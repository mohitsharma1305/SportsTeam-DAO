;; SportsTeam DAO Contract
;; Fan-owned sports team governance with voting rights and revenue sharing

;; Define the governance token for voting rights
(define-fungible-token team-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-member (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-proposal-not-found (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-voting-ended (err u106))

;; Data variables
(define-data-var total-revenue uint u0)
(define-data-var total-members uint u0)
(define-data-var proposal-counter uint u0)

;; Maps
(define-map member-shares principal uint)
(define-map member-claimed principal uint)
(define-map proposals uint {
    title: (string-ascii 100),
    description: (string-ascii 500),
    votes-for: uint,
    votes-against: uint,
    end-block: uint,
    executed: bool
})
(define-map votes { proposal-id: uint, voter: principal } bool)

;; Function 1: Purchase membership shares and get voting tokens
(define-public (purchase-membership (share-amount uint))
  (begin
    ;; Ensure share amount is valid
    (asserts! (> share-amount u0) err-invalid-amount)
    
    ;; Calculate cost (1 STX per share for simplicity)
    (let ((cost (* share-amount u1000000))) ;; 1 STX = 1,000,000 microSTX
      
      ;; Transfer STX to contract for membership
      (try! (stx-transfer? cost tx-sender (as-contract tx-sender)))
      
      ;; Add to total revenue
      (var-set total-revenue (+ (var-get total-revenue) cost))
      
      ;; Check if new member before updating
      (let ((existing-shares (default-to u0 (map-get? member-shares tx-sender))))
        (map-set member-shares tx-sender (+ existing-shares share-amount))
        (if (is-eq existing-shares u0)
            (var-set total-members (+ (var-get total-members) u1))
            true))
      
      ;; Mint governance tokens (1:1 ratio with shares)
      (try! (ft-mint? team-token share-amount tx-sender))
      
      (ok share-amount))))

;; Function 2: Claim revenue share based on ownership percentage
(define-public (claim-revenue-share)
  (let (
    (member-shares-amount (default-to u0 (map-get? member-shares tx-sender)))
    (total-supply (ft-get-supply team-token))
    (available-revenue (var-get total-revenue))
    (already-claimed (default-to u0 (map-get? member-claimed tx-sender)))
  )
    (asserts! (> member-shares-amount u0) err-not-member)
    
    ;; Calculate member's share of revenue
    (let (
      (member-percentage (/ (* member-shares-amount u100) total-supply))
      (total-claimable (/ (* available-revenue member-percentage) u100))
      (claimable-amount (- total-claimable already-claimed))
    )
      (asserts! (> claimable-amount u0) err-insufficient-balance)
      
      ;; Transfer revenue share to member
      (try! (as-contract (stx-transfer? claimable-amount tx-sender (as-contract tx-sender))))
      
      ;; Update claimed amount
      (map-set member-claimed tx-sender total-claimable)
      
      (ok claimable-amount))))

;; Read-only functions
(define-read-only (get-member-shares (member principal))
  (ok (default-to u0 (map-get? member-shares member))))

(define-read-only (get-total-revenue)
  (ok (var-get total-revenue)))

(define-read-only (get-total-members)
  (ok (var-get total-members)))

(define-read-only (get-member-voting-power (member principal))
  (ok (ft-get-balance team-token member)))

(define-read-only (get-contract-balance)
  (ok (stx-get-balance (as-contract tx-sender))))

;; Helper function to add revenue (for team earnings)
(define-public (add-team-revenue (amount uint))
  (begin
    ;; Only contract-owner can call
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)

    ;; Ensure valid amount
    (asserts! (> amount u0) err-invalid-amount)

    ;; Transfer STX into contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Safely update total revenue
    (var-set total-revenue (+ (var-get total-revenue) amount))

    (ok true)))
