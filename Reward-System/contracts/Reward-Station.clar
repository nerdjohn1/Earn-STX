;; Reward Distributor Smart Contract
;; A comprehensive reward distribution system with staking, vesting, and governance features

;; ===============================
;; CONSTANTS AND ERROR CODES
;; ===============================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-POOL-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-CLAIMED (err u104))
(define-constant ERR-NOT-ELIGIBLE (err u105))
(define-constant ERR-PERIOD-NOT-ENDED (err u106))
(define-constant ERR-INVALID-PERIOD (err u107))
(define-constant ERR-ZERO-AMOUNT (err u108))
(define-constant ERR-POOL-INACTIVE (err u109))
(define-constant ERR-VESTING-NOT-STARTED (err u110))
(define-constant ERR-ALREADY-VESTED (err u111))
(define-constant ERR-EMERGENCY-STOPPED (err u112))
(define-constant ERR-INVALID-PRINCIPAL (err u113))
(define-constant ERR-INVALID-POOL-ID (err u114))
(define-constant ERR-INVALID-STRING (err u115))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-STAKE-AMOUNT u1000000) ;; 1 STX in microSTX
(define-constant MAX-POOLS u100)
(define-constant BLOCKS-PER-DAY u144) ;; Approximate blocks per day
(define-constant PRECISION u1000000) ;; 6 decimal places for calculations

;; ===============================
;; DATA VARIABLES
;; ===============================

;; Contract state
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var total-pools uint u0)
(define-data-var emergency-stop bool false)
(define-data-var fee-percentage uint u500) ;; 5% in basis points (5000/100000)

;; ===============================
;; DATA MAPS
;; ===============================

;; Pool information
(define-map pools
  { pool-id: uint }
  {
    name: (string-ascii 50),
    total-rewards: uint,
    distributed-rewards: uint,
    start-block: uint,
    end-block: uint,
    min-stake: uint,
    max-participants: uint,
    current-participants: uint,
    active: bool,
    reward-per-block: uint,
    total-staked: uint
  }
)

;; User stakes in pools
(define-map user-stakes
  { user: principal, pool-id: uint }
  {
    amount: uint,
    stake-block: uint,
    last-claim-block: uint,
    total-claimed: uint
  }
)

;; User rewards tracking
(define-map user-rewards
  { user: principal, pool-id: uint }
  {
    pending-rewards: uint,
    total-earned: uint,
    last-update-block: uint
  }
)

;; Vesting schedules
(define-map vesting-schedules
  { user: principal, pool-id: uint }
  {
    total-amount: uint,
    vested-amount: uint,
    start-block: uint,
    duration-blocks: uint,
    cliff-blocks: uint
  }
)

;; Admin permissions
(define-map admins principal bool)

;; Pool participants list
(define-map pool-participants
  { pool-id: uint, user: principal }
  { joined-block: uint }
)

;; ===============================
;; INPUT VALIDATION FUNCTIONS
;; ===============================

(define-private (is-valid-principal (addr principal))
  (not (is-eq addr 'ST000000000000000000002AMW42H))
)

(define-private (is-valid-pool-id (pool-id uint))
  (and (> pool-id u0) (<= pool-id MAX-POOLS))
)

(define-private (is-valid-string (str (string-ascii 50)))
  (> (len str) u0)
)

;; ===============================
;; AUTHORIZATION FUNCTIONS
;; ===============================

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-admin)
  (or 
    (is-contract-owner)
    (default-to false (map-get? admins tx-sender))
  )
)

;; ===============================
;; ADMIN FUNCTIONS
;; ===============================

(define-public (set-admin (admin principal) (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-principal admin) ERR-INVALID-PRINCIPAL)
    (map-set admins admin enabled)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-principal new-owner) ERR-INVALID-PRINCIPAL)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-emergency-stop (stop bool))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (var-set emergency-stop stop)
    (ok true)
  )
)

(define-public (set-fee-percentage (fee uint))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (<= fee u10000) ERR-INVALID-AMOUNT) ;; Max 100%
    (var-set fee-percentage fee)
    (ok true)
  )
)

;; ===============================
;; POOL MANAGEMENT FUNCTIONS
;; ===============================

(define-public (create-pool 
  (name (string-ascii 50))
  (total-rewards uint)
  (duration-blocks uint)
  (min-stake uint)
  (max-participants uint)
)
  (let (
    (pool-id (+ (var-get total-pools) u1))
    (current-height burn-block-height)
    (end-block (+ current-height duration-blocks))
    (reward-per-block (/ total-rewards duration-blocks))
  )
    (asserts! (not (var-get emergency-stop)) ERR-EMERGENCY-STOPPED)
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-string name) ERR-INVALID-STRING)
    (asserts! (> total-rewards u0) ERR-ZERO-AMOUNT)
    (asserts! (> duration-blocks u0) ERR-INVALID-PERIOD)
    (asserts! (>= min-stake MIN-STAKE-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (< pool-id MAX-POOLS) ERR-INVALID-AMOUNT)
    (asserts! (> max-participants u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer rewards to contract
    (try! (stx-transfer? total-rewards tx-sender (as-contract tx-sender)))
    
    (map-set pools
      { pool-id: pool-id }
      {
        name: name,
        total-rewards: total-rewards,
        distributed-rewards: u0,
        start-block: current-height,
        end-block: end-block,
        min-stake: min-stake,
        max-participants: max-participants,
        current-participants: u0,
        active: true,
        reward-per-block: reward-per-block,
        total-staked: u0
      }
    )
    
    (var-set total-pools pool-id)
    (ok pool-id)
  )
)

(define-public (deactivate-pool (pool-id uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
  )
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-pool-id pool-id) ERR-INVALID-POOL-ID)
    (map-set pools
      { pool-id: pool-id }
      (merge pool { active: false })
    )
    (ok true)
  )
)

(define-public (extend-pool (pool-id uint) (additional-blocks uint) (additional-rewards uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
    (new-end-block (+ (get end-block pool) additional-blocks))
    (new-total-rewards (+ (get total-rewards pool) additional-rewards))
    (new-duration (- new-end-block (get start-block pool)))
    (new-reward-per-block (/ new-total-rewards new-duration))
  )
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-pool-id pool-id) ERR-INVALID-POOL-ID)
    (asserts! (get active pool) ERR-POOL-INACTIVE)
    (asserts! (> additional-rewards u0) ERR-ZERO-AMOUNT)
    (asserts! (> additional-blocks u0) ERR-INVALID-PERIOD)
    
    ;; Transfer additional rewards
    (try! (stx-transfer? additional-rewards tx-sender (as-contract tx-sender)))
    
    (map-set pools
      { pool-id: pool-id }
      (merge pool {
        end-block: new-end-block,
        total-rewards: new-total-rewards,
        reward-per-block: new-reward-per-block
      })
    )
    (ok true)
  )
)

;; ===============================
;; STAKING FUNCTIONS
;; ===============================

(define-public (stake-in-pool (pool-id uint) (amount uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
    (existing-stake (map-get? user-stakes { user: tx-sender, pool-id: pool-id }))
    (current-height burn-block-height)
  )
    (asserts! (not (var-get emergency-stop)) ERR-EMERGENCY-STOPPED)
    (asserts! (is-valid-pool-id pool-id) ERR-INVALID-POOL-ID)
    (asserts! (get active pool) ERR-POOL-INACTIVE)
    (asserts! (>= amount (get min-stake pool)) ERR-INVALID-AMOUNT)
    (asserts! (< current-height (get end-block pool)) ERR-PERIOD-NOT-ENDED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Check participant limit
    (asserts! 
      (or 
        (is-some existing-stake)
        (< (get current-participants pool) (get max-participants pool))
      ) 
      ERR-NOT-ELIGIBLE
    )
    
    ;; Transfer stake to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Handle existing or new stake
    (match existing-stake
      stake-data
      ;; Update existing stake and calculate rewards
      (let (
        (last-claim (get last-claim-block stake-data))
        (stake-amount (get amount stake-data))
        (blocks-elapsed (- current-height last-claim))
        (pool-total-staked (get total-staked pool))
        (pending-rewards (if (and (> pool-total-staked u0) (> blocks-elapsed u0))
          (/ (* (* stake-amount blocks-elapsed) (get reward-per-block pool)) pool-total-staked)
          u0))
        (current-rewards (default-to 
          { pending-rewards: u0, total-earned: u0, last-update-block: current-height }
          (map-get? user-rewards { user: tx-sender, pool-id: pool-id })
        ))
      )
        ;; Update user rewards
        (map-set user-rewards
          { user: tx-sender, pool-id: pool-id }
          {
            pending-rewards: (+ (get pending-rewards current-rewards) pending-rewards),
            total-earned: (+ (get total-earned current-rewards) pending-rewards),
            last-update-block: current-height
          }
        )
        ;; Update stake
        (map-set user-stakes
          { user: tx-sender, pool-id: pool-id }
          (merge stake-data {
            amount: (+ (get amount stake-data) amount),
            last-claim-block: current-height
          })
        )
        ;; Update pool
        (map-set pools
          { pool-id: pool-id }
          (merge pool {
            total-staked: (+ (get total-staked pool) amount)
          })
        )
      )
      ;; Create new stake
      (begin
        (map-set user-stakes
          { user: tx-sender, pool-id: pool-id }
          {
            amount: amount,
            stake-block: current-height,
            last-claim-block: current-height,
            total-claimed: u0
          }
        )
        (map-set pool-participants
          { pool-id: pool-id, user: tx-sender }
          { joined-block: current-height }
        )
        (map-set pools
          { pool-id: pool-id }
          (merge pool {
            current-participants: (+ (get current-participants pool) u1),
            total-staked: (+ (get total-staked pool) amount)
          })
        )
      )
    )
    
    (ok amount)
  )
)

(define-public (withdraw-stake (pool-id uint) (amount uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
    (stake-data (unwrap! (map-get? user-stakes { user: tx-sender, pool-id: pool-id }) ERR-NOT-ELIGIBLE))
    (current-amount (get amount stake-data))
    (current-height burn-block-height)
  )
    (asserts! (not (var-get emergency-stop)) ERR-EMERGENCY-STOPPED)
    (asserts! (is-valid-pool-id pool-id) ERR-INVALID-POOL-ID)
    (asserts! (<= amount current-amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Calculate and update rewards before withdrawing
    (let (
      (last-claim (get last-claim-block stake-data))
      (stake-amount (get amount stake-data))
      (blocks-elapsed (- current-height last-claim))
      (pool-total-staked (get total-staked pool))
      (pending-rewards (if (and (> pool-total-staked u0) (> blocks-elapsed u0))
        (/ (* (* stake-amount blocks-elapsed) (get reward-per-block pool)) pool-total-staked)
        u0))
      (current-rewards (default-to 
        { pending-rewards: u0, total-earned: u0, last-update-block: current-height }
        (map-get? user-rewards { user: tx-sender, pool-id: pool-id })
      ))
    )
      ;; Update rewards
      (map-set user-rewards
        { user: tx-sender, pool-id: pool-id }
        {
          pending-rewards: (+ (get pending-rewards current-rewards) pending-rewards),
          total-earned: (+ (get total-earned current-rewards) pending-rewards),
          last-update-block: current-height
        }
      )
      
      ;; Update stake
      (if (is-eq amount current-amount)
        ;; Complete withdrawal
        (begin
          (map-delete user-stakes { user: tx-sender, pool-id: pool-id })
          (map-delete pool-participants { pool-id: pool-id, user: tx-sender })
          (map-set pools
            { pool-id: pool-id }
            (merge pool {
              current-participants: (- (get current-participants pool) u1),
              total-staked: (- (get total-staked pool) amount)
            })
          )
        )
        ;; Partial withdrawal
        (begin
          (map-set user-stakes
            { user: tx-sender, pool-id: pool-id }
            (merge stake-data {
              amount: (- current-amount amount),
              last-claim-block: current-height
            })
          )
          (map-set pools
            { pool-id: pool-id }
            (merge pool {
              total-staked: (- (get total-staked pool) amount)
            })
          )
        )
      )
      
      ;; Transfer withdrawn amount back to user
      (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
      
      (ok amount)
    )
  )
)

;; ===============================
;; REWARD CLAIMING FUNCTIONS
;; ===============================

(define-public (collect-rewards (pool-id uint))
  (let (
    (pool (unwrap! (map-get? pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
    (stake-data (unwrap! (map-get? user-stakes { user: tx-sender, pool-id: pool-id }) ERR-NOT-ELIGIBLE))
    (current-height burn-block-height)
  )
    (asserts! (not (var-get emergency-stop)) ERR-EMERGENCY-STOPPED)
    (asserts! (is-valid-pool-id pool-id) ERR-INVALID-POOL-ID)
    
    ;; Calculate and claim rewards
    (let (
      (last-claim (get last-claim-block stake-data))
      (stake-amount (get amount stake-data))
      (blocks-elapsed (- current-height last-claim))
      (pool-total-staked (get total-staked pool))
      (calculated-rewards (if (and (> pool-total-staked u0) (> blocks-elapsed u0))
        (/ (* (* stake-amount blocks-elapsed) (get reward-per-block pool)) pool-total-staked)
        u0))
      (current-rewards (default-to 
        { pending-rewards: u0, total-earned: u0, last-update-block: current-height }
        (map-get? user-rewards { user: tx-sender, pool-id: pool-id })
      ))
      (total-pending (+ (get pending-rewards current-rewards) calculated-rewards))
      (fee-amount (/ (* total-pending (var-get fee-percentage)) u100000))
      (net-rewards (- total-pending fee-amount))
    )
      (asserts! (> total-pending u0) ERR-ZERO-AMOUNT)
      
      ;; Update user stake claim block
      (map-set user-stakes
        { user: tx-sender, pool-id: pool-id }
        (merge stake-data {
          last-claim-block: current-height,
          total-claimed: (+ (get total-claimed stake-data) net-rewards)
        })
      )
      
      ;; Reset pending rewards
      (map-set user-rewards
        { user: tx-sender, pool-id: pool-id }
        {
          pending-rewards: u0,
          total-earned: (+ (get total-earned current-rewards) calculated-rewards),
          last-update-block: current-height
        }
      )
      
      ;; Update pool distributed rewards
      (map-set pools
        { pool-id: pool-id }
        (merge pool {
          distributed-rewards: (+ (get distributed-rewards pool) total-pending)
        })
      )
      
      ;; Transfer rewards
      (try! (as-contract (stx-transfer? net-rewards tx-sender tx-sender)))
      
      ;; Transfer fee to contract owner
      (if (> fee-amount u0)
        (try! (as-contract (stx-transfer? fee-amount tx-sender (var-get contract-owner))))
        true
      )
      
      (ok net-rewards)
    )
  )
)

;; ===============================
;; VESTING FUNCTIONS
;; ===============================

(define-public (create-vesting-schedule
  (user principal)
  (pool-id uint)
  (total-amount uint)
  (duration-blocks uint)
  (cliff-blocks uint)
)
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-principal user) ERR-INVALID-PRINCIPAL)
    (asserts! (is-valid-pool-id pool-id) ERR-INVALID-POOL-ID)
    (asserts! (> total-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (> duration-blocks u0) ERR-INVALID-PERIOD)
    (asserts! (<= cliff-blocks duration-blocks) ERR-INVALID-PERIOD)
    
    (map-set vesting-schedules
      { user: user, pool-id: pool-id }
      {
        total-amount: total-amount,
        vested-amount: u0,
        start-block: burn-block-height,
        duration-blocks: duration-blocks,
        cliff-blocks: cliff-blocks
      }
    )
    (ok true)
  )
)

(define-public (claim-vested-tokens (pool-id uint))
  (let (
    (vesting (unwrap! (map-get? vesting-schedules { user: tx-sender, pool-id: pool-id }) ERR-NOT-ELIGIBLE))
    (current-height burn-block-height)
    (start-block (get start-block vesting))
    (cliff-blocks (get cliff-blocks vesting))
    (duration-blocks (get duration-blocks vesting))
    (total-amount (get total-amount vesting))
    (already-vested (get vested-amount vesting))
    (total-vested (if (< current-height (+ start-block cliff-blocks))
      u0
      (if (>= current-height (+ start-block duration-blocks))
        total-amount
        (/ (* total-amount (- current-height start-block)) duration-blocks))))
    (claimable (- total-vested already-vested))
  )
    (asserts! (not (var-get emergency-stop)) ERR-EMERGENCY-STOPPED)
    (asserts! (is-valid-pool-id pool-id) ERR-INVALID-POOL-ID)
    (asserts! (> claimable u0) ERR-ZERO-AMOUNT)
    
    ;; Update vested amount
    (map-set vesting-schedules
      { user: tx-sender, pool-id: pool-id }
      (merge vesting { vested-amount: total-vested })
    )
    
    ;; Transfer vested tokens
    (try! (as-contract (stx-transfer? claimable tx-sender tx-sender)))
    
    (ok claimable)
  )
)

;; ===============================
;; VIEW FUNCTIONS
;; ===============================

(define-read-only (get-pool-info (pool-id uint))
  (if (is-valid-pool-id pool-id)
    (map-get? pools { pool-id: pool-id })
    none
  )
)

(define-read-only (get-user-stake (user principal) (pool-id uint))
  (if (and (is-valid-principal user) (is-valid-pool-id pool-id))
    (map-get? user-stakes { user: user, pool-id: pool-id })
    none
  )
)

(define-read-only (get-pending-rewards (user principal) (pool-id uint))
  (if (and (is-valid-principal user) (is-valid-pool-id pool-id))
    (match (map-get? pools { pool-id: pool-id })
      pool
      (match (map-get? user-stakes { user: user, pool-id: pool-id })
        stake-data
        (let (
          (last-claim (get last-claim-block stake-data))
          (stake-amount (get amount stake-data))
          (blocks-elapsed (- burn-block-height last-claim))
          (pool-total-staked (get total-staked pool))
          (calculated-rewards (if (and (> pool-total-staked u0) (> blocks-elapsed u0))
            (/ (* (* stake-amount blocks-elapsed) (get reward-per-block pool)) pool-total-staked)
            u0))
          (current-rewards (default-to 
            { pending-rewards: u0, total-earned: u0, last-update-block: burn-block-height }
            (map-get? user-rewards { user: user, pool-id: pool-id })
          ))
        )
          (some {
            pending-rewards: (+ (get pending-rewards current-rewards) calculated-rewards),
            total-earned: (get total-earned current-rewards),
            last-update-block: (get last-update-block current-rewards)
          })
        )
        none
      )
      none
    )
    none
  )
)

(define-read-only (get-vesting-info (user principal) (pool-id uint))
  (if (and (is-valid-principal user) (is-valid-pool-id pool-id))
    (match (map-get? vesting-schedules { user: user, pool-id: pool-id })
      vesting
      (let (
        (current-height burn-block-height)
        (start-block (get start-block vesting))
        (cliff-blocks (get cliff-blocks vesting))
        (duration-blocks (get duration-blocks vesting))
        (total-amount (get total-amount vesting))
        (already-vested (get vested-amount vesting))
        (total-vested (if (< current-height (+ start-block cliff-blocks))
          u0
          (if (>= current-height (+ start-block duration-blocks))
            total-amount
            (/ (* total-amount (- current-height start-block)) duration-blocks))))
        (claimable (- total-vested already-vested))
      )
        (some {
          total-amount: total-amount,
          vested-amount: already-vested,
          claimable: claimable,
          start-block: start-block,
          duration-blocks: duration-blocks,
          cliff-blocks: cliff-blocks
        })
      )
      none
    )
    none
  )
)

(define-read-only (get-total-pools)
  (var-get total-pools)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (is-pool-participant (pool-id uint) (user principal))
  (if (and (is-valid-pool-id pool-id) (is-valid-principal user))
    (is-some (map-get? pool-participants { pool-id: pool-id, user: user }))
    false
  )
)

(define-read-only (get-emergency-stop)
  (var-get emergency-stop)
)

(define-read-only (get-fee-percentage)
  (var-get fee-percentage)
)

;; ===============================
;; EMERGENCY FUNCTIONS
;; ===============================

(define-public (emergency-withdraw (pool-id uint))
  (let (
    (stake-data (unwrap! (map-get? user-stakes { user: tx-sender, pool-id: pool-id }) ERR-NOT-ELIGIBLE))
    (amount (get amount stake-data))
  )
    (asserts! (var-get emergency-stop) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-pool-id pool-id) ERR-INVALID-POOL-ID)
    
    ;; Remove stake
    (map-delete user-stakes { user: tx-sender, pool-id: pool-id })
    (map-delete pool-participants { pool-id: pool-id, user: tx-sender })
    
    ;; Transfer stake back
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    
    (ok amount)
  )
)

;; Contract initialization
(begin
  (map-set admins CONTRACT-OWNER true)
)