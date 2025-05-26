;; Implementation Tracking Contract
;; Monitors innovation adoption and deployment

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_NOT_FOUND (err u501))
(define-constant ERR_INVALID_STATUS (err u502))
(define-constant ERR_ALREADY_EXISTS (err u503))

;; Data structures
(define-map implementations
  { implementation-id: uint }
  {
    solution-id: uint,
    implementer: principal,
    title: (string-ascii 200),
    description: (string-ascii 1000),
    status: (string-ascii 20),
    started-at: uint,
    completed-at: uint,
    success-rate: uint,
    deployment-type: (string-ascii 50)
  }
)

(define-map implementation-metrics
  { implementation-id: uint }
  {
    production-volume: uint,
    quality-improvement: uint,
    cost-reduction: uint,
    time-savings: uint,
    efficiency-gain: uint,
    last-updated: uint
  }
)

(define-map implementation-phases
  { implementation-id: uint, phase-id: uint }
  {
    phase-name: (string-ascii 100),
    description: (string-ascii 500),
    start-date: uint,
    end-date: uint,
    status: (string-ascii 20),
    completion-percentage: uint,
    responsible-party: principal
  }
)

(define-map adoption-feedback
  { implementation-id: uint, feedback-id: uint }
  {
    reviewer: principal,
    rating: uint,
    comments: (string-ascii 500),
    feedback-type: (string-ascii 50),
    submitted-at: uint,
    verified: bool
  }
)

(define-data-var next-implementation-id uint u1)
(define-data-var next-phase-id uint u1)
(define-data-var next-feedback-id uint u1)

;; Public functions
(define-public (start-implementation
  (solution-id uint)
  (title (string-ascii 200))
  (description (string-ascii 1000))
  (deployment-type (string-ascii 50))
)
  (let ((implementation-id (var-get next-implementation-id)))
    (map-set implementations
      { implementation-id: implementation-id }
      {
        solution-id: solution-id,
        implementer: tx-sender,
        title: title,
        description: description,
        status: "planning",
        started-at: block-height,
        completed-at: u0,
        success-rate: u0,
        deployment-type: deployment-type
      }
    )

    (map-set implementation-metrics
      { implementation-id: implementation-id }
      {
        production-volume: u0,
        quality-improvement: u0,
        cost-reduction: u0,
        time-savings: u0,
        efficiency-gain: u0,
        last-updated: block-height
      }
    )

    (var-set next-implementation-id (+ implementation-id u1))
    (ok implementation-id)
  )
)

(define-public (add-implementation-phase
  (implementation-id uint)
  (phase-name (string-ascii 100))
  (description (string-ascii 500))
  (start-date uint)
  (end-date uint)
  (responsible-party principal)
)
  (let ((implementation (unwrap! (map-get? implementations { implementation-id: implementation-id }) ERR_NOT_FOUND))
        (phase-id (var-get next-phase-id)))
    (asserts! (is-eq tx-sender (get implementer implementation)) ERR_UNAUTHORIZED)

    (map-set implementation-phases
      { implementation-id: implementation-id, phase-id: phase-id }
      {
        phase-name: phase-name,
        description: description,
        start-date: start-date,
        end-date: end-date,
        status: "planned",
        completion-percentage: u0,
        responsible-party: responsible-party
      }
    )

    (var-set next-phase-id (+ phase-id u1))
    (ok phase-id)
  )
)

(define-public (update-phase-progress (implementation-id uint) (phase-id uint) (completion-percentage uint) (status (string-ascii 20)))
  (let ((implementation (unwrap! (map-get? implementations { implementation-id: implementation-id }) ERR_NOT_FOUND))
        (phase (unwrap! (map-get? implementation-phases { implementation-id: implementation-id, phase-id: phase-id }) ERR_NOT_FOUND)))
    (asserts! (or
      (is-eq tx-sender (get implementer implementation))
      (is-eq tx-sender (get responsible-party phase))
    ) ERR_UNAUTHORIZED)
    (asserts! (<= completion-percentage u100) ERR_INVALID_STATUS)

    (map-set implementation-phases
      { implementation-id: implementation-id, phase-id: phase-id }
      (merge phase {
        completion-percentage: completion-percentage,
        status: status
      })
    )
    (ok true)
  )
)

(define-public (update-metrics
  (implementation-id uint)
  (production-volume uint)
  (quality-improvement uint)
  (cost-reduction uint)
  (time-savings uint)
  (efficiency-gain uint)
)
  (let ((implementation (unwrap! (map-get? implementations { implementation-id: implementation-id }) ERR_NOT_FOUND))
        (metrics (unwrap! (map-get? implementation-metrics { implementation-id: implementation-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get implementer implementation)) ERR_UNAUTHORIZED)

    (map-set implementation-metrics
      { implementation-id: implementation-id }
      {
        production-volume: production-volume,
        quality-improvement: quality-improvement,
        cost-reduction: cost-reduction,
        time-savings: time-savings,
        efficiency-gain: efficiency-gain,
        last-updated: block-height
      }
    )
    (ok true)
  )
)

(define-public (submit-feedback
  (implementation-id uint)
  (rating uint)
  (comments (string-ascii 500))
  (feedback-type (string-ascii 50))
)
  (let ((implementation (unwrap! (map-get? implementations { implementation-id: implementation-id }) ERR_NOT_FOUND))
        (feedback-id (var-get next-feedback-id)))
    (asserts! (<= rating u5) ERR_INVALID_STATUS)

    (map-set adoption-feedback
      { implementation-id: implementation-id, feedback-id: feedback-id }
      {
        reviewer: tx-sender,
        rating: rating,
        comments: comments,
        feedback-type: feedback-type,
        submitted-at: block-height,
        verified: false
      }
    )

    (var-set next-feedback-id (+ feedback-id u1))
    (ok feedback-id)
  )
)

(define-public (verify-feedback (implementation-id uint) (feedback-id uint))
  (let ((implementation (unwrap! (map-get? implementations { implementation-id: implementation-id }) ERR_NOT_FOUND))
        (feedback (unwrap! (map-get? adoption-feedback { implementation-id: implementation-id, feedback-id: feedback-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get implementer implementation)) ERR_UNAUTHORIZED)

    (map-set adoption-feedback
      { implementation-id: implementation-id, feedback-id: feedback-id }
      (merge feedback { verified: true })
    )
    (ok true)
  )
)

(define-public (complete-implementation (implementation-id uint) (success-rate uint))
  (let ((implementation (unwrap! (map-get? implementations { implementation-id: implementation-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get implementer implementation)) ERR_UNAUTHORIZED)
    (asserts! (<= success-rate u100) ERR_INVALID_STATUS)

    (map-set implementations
      { implementation-id: implementation-id }
      (merge implementation {
        status: "completed",
        completed-at: block-height,
        success-rate: success-rate
      })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-implementation (implementation-id uint))
  (map-get? implementations { implementation-id: implementation-id })
)

(define-read-only (get-implementation-metrics (implementation-id uint))
  (map-get? implementation-metrics { implementation-id: implementation-id })
)

(define-read-only (get-implementation-phase (implementation-id uint) (phase-id uint))
  (map-get? implementation-phases { implementation-id: implementation-id, phase-id: phase-id })
)

(define-read-only (get-feedback (implementation-id uint) (feedback-id uint))
  (map-get? adoption-feedback { implementation-id: implementation-id, feedback-id: feedback-id })
)

(define-read-only (is-implementation-active (implementation-id uint))
  (match (map-get? implementations { implementation-id: implementation-id })
    implementation (not (is-eq (get status implementation) "completed"))
    false
  )
)
