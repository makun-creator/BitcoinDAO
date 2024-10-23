;; Bitcoin-Based DAO Contract
;; Implements governance, voting, fund management, and investment tracking
;; Adds delegation, investment returns, emergency controls, and governance parameters

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-VOTED (err u101))
(define-constant ERR-PROPOSAL-EXPIRED (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u105))
(define-constant ERR-QUORUM-NOT-REACHED (err u106))


;; Additional Error codes
(define-constant ERR-NO-DELEGATE (err u110))
(define-constant ERR-INVALID-DELEGATE (err u111))
(define-constant ERR-EMERGENCY-ACTIVE (err u112))
(define-constant ERR-NOT-EMERGENCY (err u113))
(define-constant ERR-INVALID-PARAMETER (err u114))
(define-constant ERR-NO-RETURNS (err u115))

;; Data variables
(define-data-var dao-admin principal tx-sender)
(define-data-var minimum-quorum uint u500) ;; 50% in basis points
(define-data-var voting-period uint u144) ;; ~1 day in blocks
(define-data-var proposal-count uint u0)
(define-data-var treasury-balance uint u0)

;; Data Maps
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

(define-map emergency-admins principal bool)

(define-map delegations
    principal
    {
        delegate: principal,
        amount: uint,
        expiry: uint
    }
)

(define-map return-pools
    uint
    {
        total-amount: uint,
        distributed-amount: uint,
        distribution-start: uint,
        distribution-end: uint,
        claims: (list 200 principal)
    }
)

(define-map member-claims
    {member: principal, pool-id: uint}
    {
        amount: uint,
        claimed: bool
    }
)

;; Public functions
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
        (try! (stx-transfer? amount caller (contract-caller)))
        (map-set members 
            caller
            (merge member-info {
                voting-power: (+ (get voting-power member-info) amount),
                total-contributed: new-total
            })
        )
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        (ok true)
    )
)

;; Governance Parameters
(define-data-var dao-parameters
    {
        proposal-fee: uint,
        min-proposal-amount: uint,
        max-proposal-amount: uint,
        voting-delay: uint,
        voting-period: uint,
        timelock-period: uint,
        quorum-threshold: uint,
        super-majority: uint
    }
    {
        proposal-fee: u100000, ;; 0.1 STX
        min-proposal-amount: u1000000, ;; 1 STX
        max-proposal-amount: u1000000000, ;; 1000 STX
        voting-delay: u100, ;; blocks before voting starts
        voting-period: u144, ;; ~1 day in blocks
        timelock-period: u72, ;; ~12 hours in blocks
        quorum-threshold: u500, ;; 50% in basis points
        super-majority: u667 ;; 66.7% in basis points
    }
)

;; Emergency Control
(define-data-var emergency-state bool false)
(define-map emergency-admins principal bool)

;; Delegation System
(define-map delegations
    principal
    {
        delegate: principal,
        amount: uint,
        expiry: uint
    }
)

;; Investment Returns
(define-map return-pools
    uint  ;; proposal ID
    {
        total-amount: uint,
        distributed-amount: uint,
        distribution-start: uint,
        distribution-end: uint,
        claims: (list 200 principal)
    }
)

;; Member claims
(define-map member-claims
    {member: principal, pool-id: uint}
    {
        amount: uint,
        claimed: bool
    }
)

;; Emergency Controls

(define-public (set-emergency-state (state bool))
    (begin
        (asserts! (is-emergency-admin tx-sender) ERR-NOT-AUTHORIZED)
        (var-set emergency-state state)
        (ok true)
    )
)

(define-public (add-emergency-admin (admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get dao-admin)) ERR-NOT-AUTHORIZED)
        (map-set emergency-admins admin true)
        (ok true)
    )
)

;; Delegation System

(define-public (delegate-votes (delegate-to principal) (amount uint) (expiry uint))
    (let
        (
            (caller tx-sender)
            (member-info (unwrap! (get-member-info caller) ERR-NOT-AUTHORIZED))
        )
        (asserts! (>= (get voting-power member-info) amount) ERR-INSUFFICIENT-FUNDS)
        (asserts! (> expiry block-height) ERR-INVALID-PARAMETER)
        
        (map-set delegations
            caller
            {
                delegate: delegate-to,
                amount: amount,
                expiry: expiry
            }
        )
        
        ;; Update voting power
        (map-set members
            caller
            (merge member-info {
                voting-power: (- (get voting-power member-info) amount)
            })
        )
        (ok true)
    )
)

(define-public (revoke-delegation)
    (let
        (
            (caller tx-sender)
            (delegation (unwrap! (get-delegation caller) ERR-NO-DELEGATE))
            (member-info (unwrap! (get-member-info caller) ERR-NOT-AUTHORIZED))
        )
        ;; Return voting power
        (map-set members
            caller
            (merge member-info {
                voting-power: (+ (get voting-power member-info) (get amount delegation))
            })
        )
        ;; Clear delegation
        (map-delete delegations caller)
        (ok true)
    )
)

(define-public (create-proposal 
    (title (string-ascii 100))
    (description (string-utf8 1000))
    (amount uint)
    (target principal))
    (let
        (
            (caller tx-sender)
            (current-block block-height)
            (proposal-id (+ (var-get proposal-count) u1))
            (params (var-get dao-parameters))
            (end-block (+ current-block (get voting-period params)))
        )
        (asserts! (is-some (get-member-info caller)) ERR-NOT-AUTHORIZED)
        (asserts! (>= (var-get treasury-balance) amount) ERR-INSUFFICIENT-FUNDS)
        (asserts! (>= amount (get min-proposal-amount params)) ERR-INVALID-AMOUNT)
        (asserts! (<= amount (get max-proposal-amount params)) ERR-INVALID-AMOUNT)
        
        (try! (stx-transfer? (get proposal-fee params) caller (as-contract tx-sender)))
        
        (map-set proposals 
            proposal-id
            {
                id: proposal-id,
                proposer: caller,
                title: title,
                description: description,
                amount: amount,
                target: target,
                start-block: (+ current-block (get voting-delay params)),
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
        
        (map-set votes 
            {proposal-id: proposal-id, voter: caller}
            {amount: voting-power, support: support}
        )
        
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

(define-public (execute-proposal (proposal-id uint))
    (let
        (
            (proposal (unwrap! (get-proposal-by-id proposal-id) ERR-PROPOSAL-NOT-ACTIVE))
            (params (var-get dao-parameters))
            (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
            (quorum-reached (>= (* total-votes u1000) 
                              (* (var-get treasury-balance) (get quorum-threshold params))))
        )
        (asserts! (>= block-height (get end-block proposal)) ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (not (get executed proposal)) (err u108))
        (asserts! quorum-reached ERR-QUORUM-NOT-REACHED)
        
        (if (> (get yes-votes proposal) (get no-votes proposal))
            (begin
                (try! (stx-transfer? (get amount proposal) 
                                   (as-contract tx-sender)
                                   (get target proposal)))
                (var-set treasury-balance (- (var-get treasury-balance) (get amount proposal)))
                (map-set proposals
                    proposal-id
                    (merge proposal {
                        status: "executed",
                        executed: true
                    })
                )
                (ok true)
            )
            (begin
                (map-set proposals
                    proposal-id
                    (merge proposal {
                        status: "rejected",
                        executed: true
                    })
                )
                (ok true)
            )
        )
    )
)

;; Investment Returns Management

(define-public (create-return-pool (proposal-id uint) (total-amount uint))
    (let
        (
            (caller tx-sender)
            (proposal (unwrap! (get-proposal-by-id proposal-id) ERR-PROPOSAL-NOT-ACTIVE))
        )
        (asserts! (is-eq caller (var-get dao-admin)) ERR-NOT-AUTHORIZED)
        (asserts! (> total-amount u0) ERR-INVALID-AMOUNT)
        
        (map-set return-pools
            proposal-id
            {
                total-amount: total-amount,
                distributed-amount: u0,
                distribution-start: block-height,
                distribution-end: (+ block-height (get timelock-period (var-get dao-parameters))),
                claims: (list)
            }
        )
        (ok true)
    )
)

(define-public (claim-returns (proposal-id uint))
    (let
        (
            (caller tx-sender)
            (pool (unwrap! (get-return-pool proposal-id) ERR-NO-RETURNS))
            (member-info (unwrap! (get-member-info caller) ERR-NOT-AUTHORIZED))
            (claim-amount (calculate-member-share caller proposal-id))
        )
        (asserts! (> claim-amount u0) ERR-INVALID-AMOUNT)
        (asserts! (not (has-claimed caller proposal-id)) ERR-ALREADY-VOTED)
        
        ;; Record claim
        (map-set member-claims
            {member: caller, pool-id: proposal-id}
            {
                amount: claim-amount,
                claimed: true
            }
        )
        
        ;; Update pool
        (map-set return-pools
            proposal-id
            (merge pool {
                distributed-amount: (+ (get distributed-amount pool) claim-amount),
                claims: (unwrap! (as-max-len? 
                    (append (get claims pool) caller)
                    u200
                ) ERR-INVALID-PARAMETER)
            })
        )
        
        ;; Transfer returns
        (try! (stx-transfer? claim-amount (as-contract tx-sender) caller))
        (ok true)
    )
)

;; Governance Parameter Updates

(define-public (update-dao-parameters (new-params {
    proposal-fee: uint,
    min-proposal-amount: uint,
    max-proposal-amount: uint,
    voting-delay: uint,
    voting-period: uint,
    timelock-period: uint,
    quorum-threshold: uint,
    super-majority: uint
}))
    (begin
        (asserts! (is-eq tx-sender (var-get dao-admin)) ERR-NOT-AUTHORIZED)
        (asserts! (validate-parameters new-params) ERR-INVALID-PARAMETER)
        (var-set dao-parameters new-params)
        (ok true)
    )
)

;; Helper functions

(define-private (calculate-member-share (member principal) (pool-id uint))
    (let
        (
            (pool (unwrap! (get-return-pool pool-id) u0))
            (member-info (unwrap! (get-member-info member) u0))
            (total-shares (var-get treasury-balance))
        )
        (if (> total-shares u0)
            (/ (* (get total-amount pool) (get voting-power member-info)) total-shares)
            u0
        )
    )
)

(define-private (validate-parameters (params {
    proposal-fee: uint,
    min-proposal-amount: uint,
    max-proposal-amount: uint,
    voting-delay: uint,
    voting-period: uint,
    timelock-period: uint,
    quorum-threshold: uint,
    super-majority: uint
}))
    (and
        (< (get min-proposal-amount params) (get max-proposal-amount params))
        (<= (get quorum-threshold params) u1000)
        (<= (get super-majority params) u1000)
        (> (get voting-period params) (get voting-delay params))
    )
)

;; Read-only functions
(define-read-only (get-member-info (member principal))
    (map-get? members member)
)

(define-read-only (get-proposal-by-id (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-delegation (member principal))
    (map-get? delegations member)
)

(define-read-only (get-return-pool (pool-id uint))
    (map-get? return-pools pool-id)
)

(define-read-only (has-claimed (member principal) (pool-id uint))
    (default-to false (get claimed (map-get? member-claims {member: member, pool-id: pool-id})))
)

(define-read-only (is-emergency-admin (admin principal))
    (default-to false (map-get? emergency-admins admin))
)

(define-read-only (get-dao-parameters)
    (ok (var-get dao-parameters))
)

(define-read-only (get-treasury-balance)
    (ok (var-get treasury-balance))
)