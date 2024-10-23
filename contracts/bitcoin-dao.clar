(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-VOTED (err u101))
(define-constant ERR-PROPOSAL-EXPIRED (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u105))
(define-constant ERR-QUORUM-NOT-REACHED (err u106))

(define-data-var dao-admin principal tx-sender)
(define-data-var minimum-quorum uint u500) ;; 50% in basis points
(define-data-var voting-period uint u144) ;; ~1 day in blocks
(define-data-var proposal-count uint u0)
(define-data-var treasury-balance uint u0)

(define-map members 
    principal 
    {
        voting-power: uint,
        joined-block: uint,
        total-contributed: uint,
        last-withdrawal: uint
    }
)

(define-map proposals 
    uint 
    {
        id: uint,
        proposer: principal,
        title: (string-ascii 100),
        description: (string-utf8 1000),
        amount: uint,
        target: principal,
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint,
        status: (string-ascii 20),
        executed: bool
    }
)

(define-map votes 
    {proposal-id: uint, voter: principal} 
    {
        amount: uint,
        support: bool
    }
)

(define-map investment-returns
    uint
    {
        proposal-id: uint,
        amount: uint,
        timestamp: uint,
        distributed: bool
    }
)

(define-public (join-dao)
    (let
        (
            (caller tx-sender)
            (current-block block-height)
        )
        (asserts! (is-none (get-member-info caller)) (err u107))
        (map-set members 
            caller
            {
                voting-power: u0,
                joined-block: current-block,
                total-contributed: u0,
                last-withdrawal: current-block
            }
        )
        (ok true)
    )
)


(define-public (contribute-funds (amount uint))
    (let
        (
            (caller tx-sender)
            (member-info (unwrap! (get-member-info caller) ERR-NOT-AUTHORIZED))
            (new-total (+ (get total-contributed member-info) amount))
        )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        ;; Transfer funds to contract
        (try! (stx-transfer? amount caller (contract-caller)))
        ;; Update member info
        (map-set members 
            caller
            (merge member-info {
                voting-power: (+ (get voting-power member-info) amount),
                total-contributed: new-total
            })
        )
        ;; Update treasury
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        (ok true)
    )
)

(define-public (create-proposal (title (string-ascii 100)) 
                              (description (string-utf8 1000))
                              (amount uint)
                              (target principal))
    (let
        (
            (caller tx-sender)
            (current-block block-height)
            (proposal-id (+ (var-get proposal-count) u1))
            (end-block (+ current-block (var-get voting-period)))
        )
        (asserts! (is-some (get-member-info caller)) ERR-NOT-AUTHORIZED)
        (asserts! (>= (var-get treasury-balance) amount) ERR-INSUFFICIENT-FUNDS)
        
        (map-set proposals 
            proposal-id
            {
                id: proposal-id,
                proposer: caller,
                title: title,
                description: description,
                amount: amount,
                target: target,
                start-block: current-block,
                end-block: end-block,
                yes-votes: u0,
                no-votes: u0,
                status: "active",
                executed: false
            }
        )
        (var-set proposal-count proposal-id)
        (ok proposal-id)
    )
)

(define-public (vote (proposal-id uint) (support bool))
    (let
        (
            (caller tx-sender)
            (member-info (unwrap! (get-member-info caller) ERR-NOT-AUTHORIZED))
            (proposal (unwrap! (get-proposal-by-id proposal-id) ERR-PROPOSAL-NOT-ACTIVE))
            (voting-power (get voting-power member-info))
        )
        (asserts! (< block-height (get end-block proposal)) ERR-PROPOSAL-EXPIRED)
        (asserts! (is-none (get-vote proposal-id caller)) ERR-ALREADY-VOTED)
        
        ;; Record vote
        (map-set votes 
            {proposal-id: proposal-id, voter: caller}
            {amount: voting-power, support: support}
        )
        
        ;; Update proposal vote counts
        (map-set proposals
            proposal-id
            (merge proposal {
                yes-votes: (if support 
                    (+ (get yes-votes proposal) voting-power)
                    (get yes-votes proposal)),
                no-votes: (if support 
                    (get no-votes proposal)
                    (+ (get no-votes proposal) voting-power))
            })
        )
        (ok true)
    )
)