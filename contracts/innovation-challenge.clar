;; Innovation Challenge Contract
;; Records and manages collaborative problems

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_INVALID_STATUS (err u202))
(define-constant ERR_CHALLENGE_CLOSED (err u203))

;; Data structures
(define-map challenges
  { challenge-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 1000),
    creator: principal,
    reward-amount: uint,
    status: (string-ascii 20),
    created-at: uint,
    deadline: uint,
    category: (string-ascii 50),
    difficulty-level: uint
  }
)

(define-map challenge-participants
  { challenge-id: uint, participant: principal }
  {
    joined-at: uint,
    contribution-score: uint,
    role: (string-ascii 30)
  }
)

(define-map challenge-requirements
  { challenge-id: uint }
  {
    technical-specs: (list 10 (string-ascii 100)),
    required-certifications: (list 5 (string-ascii 50)),
    minimum-capacity: uint,
    collaboration-type: (string-ascii 50)
  }
)

(define-data-var next-challenge-id uint u1)

;; Public functions
(define-public (create-challenge
  (title (string-ascii 200))
  (description (string-ascii 1000))
  (reward-amount uint)
  (deadline uint)
  (category (string-ascii 50))
  (difficulty-level uint)
  (technical-specs (list 10 (string-ascii 100)))
  (required-certifications (list 5 (string-ascii 50)))
  (minimum-capacity uint)
)
  (let ((challenge-id (var-get next-challenge-id)))
    (asserts! (> deadline block-height) ERR_INVALID_STATUS)
    (asserts! (<= difficulty-level u5) ERR_INVALID_STATUS)

    (map-set challenges
      { challenge-id: challenge-id }
      {
        title: title,
        description: description,
        creator: tx-sender,
        reward-amount: reward-amount,
        status: "open",
        created-at: block-height,
        deadline: deadline,
        category: category,
        difficulty-level: difficulty-level
      }
    )

    (map-set challenge-requirements
      { challenge-id: challenge-id }
      {
        technical-specs: technical-specs,
        required-certifications: required-certifications,
        minimum-capacity: minimum-capacity,
        collaboration-type: "open"
      }
    )

    (var-set next-challenge-id (+ challenge-id u1))
    (ok challenge-id)
  )
)

(define-public (join-challenge (challenge-id uint) (role (string-ascii 30)))
  (let ((challenge (unwrap! (map-get? challenges { challenge-id: challenge-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq (get status challenge) "open") ERR_CHALLENGE_CLOSED)
    (asserts! (< block-height (get deadline challenge)) ERR_CHALLENGE_CLOSED)

    (map-set challenge-participants
      { challenge-id: challenge-id, participant: tx-sender }
      {
        joined-at: block-height,
        contribution-score: u0,
        role: role
      }
    )
    (ok true)
  )
)

(define-public (update-challenge-status (challenge-id uint) (new-status (string-ascii 20)))
  (let ((challenge (unwrap! (map-get? challenges { challenge-id: challenge-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator challenge)) ERR_UNAUTHORIZED)

    (map-set challenges
      { challenge-id: challenge-id }
      (merge challenge { status: new-status })
    )
    (ok true)
  )
)

(define-public (update-contribution-score (challenge-id uint) (participant principal) (score uint))
  (let ((challenge (unwrap! (map-get? challenges { challenge-id: challenge-id }) ERR_NOT_FOUND))
        (participation (unwrap! (map-get? challenge-participants { challenge-id: challenge-id, participant: participant }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator challenge)) ERR_UNAUTHORIZED)

    (map-set challenge-participants
      { challenge-id: challenge-id, participant: participant }
      (merge participation { contribution-score: score })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-challenge (challenge-id uint))
  (map-get? challenges { challenge-id: challenge-id })
)

(define-read-only (get-challenge-requirements (challenge-id uint))
  (map-get? challenge-requirements { challenge-id: challenge-id })
)

(define-read-only (get-participant-info (challenge-id uint) (participant principal))
  (map-get? challenge-participants { challenge-id: challenge-id, participant: participant })
)

(define-read-only (is-challenge-active (challenge-id uint))
  (match (map-get? challenges { challenge-id: challenge-id })
    challenge (and
      (is-eq (get status challenge) "open")
      (< block-height (get deadline challenge))
    )
    false
  )
)
