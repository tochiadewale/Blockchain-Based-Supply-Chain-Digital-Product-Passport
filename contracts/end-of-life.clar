;; End-of-Life Contract
;; Manages product disposal and recycling

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_PRODUCT_NOT_FOUND (err u501))
(define-constant ERR_ALREADY_DISPOSED (err u502))
(define-constant ERR_INVALID_METHOD (err u503))

;; End-of-life records
(define-map eol-records
  { product-id: (string-ascii 64) }
  {
    disposal-method: (string-ascii 32), ;; recycle, refurbish, dispose, donate
    disposal-facility: (string-ascii 128),
    disposal-date: uint,
    materials-recovered: (list 10 (string-ascii 64)),
    recovery-percentage: uint,
    disposal-cost: uint,
    environmental-impact: uint,
    handler: principal,
    certification-hash: (string-ascii 64)
  }
)

;; Recycling facilities
(define-map authorized-recyclers principal bool)

;; Material recovery tracking
(define-map material-recovery
  { material-type: (string-ascii 64), facility: principal }
  {
    total-recovered: uint,
    recovery-rate: uint,
    last-updated: uint
  }
)

;; Disposal incentives
(define-map disposal-incentives
  { product-id: (string-ascii 64) }
  {
    incentive-amount: uint,
    incentive-type: (string-ascii 32),
    claimed: bool,
    claim-deadline: uint
  }
)

;; Record end-of-life disposal
(define-public (record-disposal
  (product-id (string-ascii 64))
  (disposal-method (string-ascii 32))
  (disposal-facility (string-ascii 128))
  (materials-recovered (list 10 (string-ascii 64)))
  (recovery-percentage uint)
  (disposal-cost uint)
  (environmental-impact uint)
  (certification-hash (string-ascii 64)))
  (begin
    (asserts! (is-none (map-get? eol-records { product-id: product-id })) ERR_ALREADY_DISPOSED)
    (asserts! (<= recovery-percentage u100) ERR_INVALID_METHOD)
    (asserts! (or (is-eq disposal-method "recycle")
                  (is-eq disposal-method "refurbish")
                  (is-eq disposal-method "dispose")
                  (is-eq disposal-method "donate")) ERR_INVALID_METHOD)

    (map-set eol-records
      { product-id: product-id }
      {
        disposal-method: disposal-method,
        disposal-facility: disposal-facility,
        disposal-date: block-height,
        materials-recovered: materials-recovered,
        recovery-percentage: recovery-percentage,
        disposal-cost: disposal-cost,
        environmental-impact: environmental-impact,
        handler: tx-sender,
        certification-hash: certification-hash
      }
    )
    (ok true)
  )
)

;; Update material recovery stats
(define-public (update-material-recovery
  (material-type (string-ascii 64))
  (amount-recovered uint)
  (recovery-rate uint))
  (let (
    (current-stats (map-get? material-recovery { material-type: material-type, facility: tx-sender }))
  )
    (asserts! (<= recovery-rate u100) ERR_INVALID_METHOD)

    (match current-stats
      existing-stats
        (map-set material-recovery
          { material-type: material-type, facility: tx-sender }
          {
            total-recovered: (+ (get total-recovered existing-stats) amount-recovered),
            recovery-rate: recovery-rate,
            last-updated: block-height
          }
        )
      (map-set material-recovery
        { material-type: material-type, facility: tx-sender }
        {
          total-recovered: amount-recovered,
          recovery-rate: recovery-rate,
          last-updated: block-height
        }
      )
    )
    (ok true)
  )
)

;; Set disposal incentive
(define-public (set-disposal-incentive
  (product-id (string-ascii 64))
  (incentive-amount uint)
  (incentive-type (string-ascii 32))
  (claim-deadline uint))
  (begin
    (asserts! (> claim-deadline block-height) ERR_INVALID_METHOD)

    (map-set disposal-incentives
      { product-id: product-id }
      {
        incentive-amount: incentive-amount,
        incentive-type: incentive-type,
        claimed: false,
        claim-deadline: claim-deadline
      }
    )
    (ok true)
  )
)

;; Claim disposal incentive
(define-public (claim-disposal-incentive (product-id (string-ascii 64)))
  (let (
    (incentive (unwrap! (map-get? disposal-incentives { product-id: product-id }) ERR_PRODUCT_NOT_FOUND))
    (eol-record (unwrap! (map-get? eol-records { product-id: product-id }) ERR_PRODUCT_NOT_FOUND))
  )
    (asserts! (not (get claimed incentive)) ERR_ALREADY_DISPOSED)
    (asserts! (< block-height (get claim-deadline incentive)) ERR_INVALID_METHOD)
    (asserts! (is-eq (get handler eol-record) tx-sender) ERR_UNAUTHORIZED)

    (map-set disposal-incentives
      { product-id: product-id }
      (merge incentive { claimed: true })
    )
    (ok (get incentive-amount incentive))
  )
)

;; Authorize recycler
(define-public (authorize-recycler (recycler principal))
  (begin
    (map-set authorized-recyclers recycler true)
    (ok true)
  )
)

;; Get end-of-life record
(define-read-only (get-eol-record (product-id (string-ascii 64)))
  (map-get? eol-records { product-id: product-id })
)

;; Get material recovery stats
(define-read-only (get-material-recovery (material-type (string-ascii 64)) (facility principal))
  (map-get? material-recovery { material-type: material-type, facility: facility })
)

;; Get disposal incentive
(define-read-only (get-disposal-incentive (product-id (string-ascii 64)))
  (map-get? disposal-incentives { product-id: product-id })
)

;; Check if product is disposed
(define-read-only (is-product-disposed (product-id (string-ascii 64)))
  (is-some (map-get? eol-records { product-id: product-id }))
)
