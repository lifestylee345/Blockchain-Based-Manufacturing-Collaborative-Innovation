;; Manufacturer Verification Contract
;; Validates and manages production entities

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Data structures
(define-map manufacturers
  { manufacturer-id: uint }
  {
    name: (string-ascii 100),
    address: principal,
    verification-status: (string-ascii 20),
    certification-level: uint,
    verified-at: uint,
    verifier: principal
  }
)

(define-map manufacturer-capabilities
  { manufacturer-id: uint }
  {
    production-capacity: uint,
    quality-certifications: (list 10 (string-ascii 50)),
    specializations: (list 5 (string-ascii 50))
  }
)

(define-data-var next-manufacturer-id uint u1)

;; Public functions
(define-public (register-manufacturer (name (string-ascii 100)) (production-capacity uint) (specializations (list 5 (string-ascii 50))))
  (let ((manufacturer-id (var-get next-manufacturer-id)))
    (asserts! (is-none (map-get? manufacturers { manufacturer-id: manufacturer-id })) ERR_ALREADY_VERIFIED)

    (map-set manufacturers
      { manufacturer-id: manufacturer-id }
      {
        name: name,
        address: tx-sender,
        verification-status: "pending",
        certification-level: u0,
        verified-at: u0,
        verifier: CONTRACT_OWNER
      }
    )

    (map-set manufacturer-capabilities
      { manufacturer-id: manufacturer-id }
      {
        production-capacity: production-capacity,
        quality-certifications: (list),
        specializations: specializations
      }
    )

    (var-set next-manufacturer-id (+ manufacturer-id u1))
    (ok manufacturer-id)
  )
)

(define-public (verify-manufacturer (manufacturer-id uint) (certification-level uint))
  (let ((manufacturer (unwrap! (map-get? manufacturers { manufacturer-id: manufacturer-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= certification-level u5) ERR_INVALID_STATUS)

    (map-set manufacturers
      { manufacturer-id: manufacturer-id }
      (merge manufacturer {
        verification-status: "verified",
        certification-level: certification-level,
        verified-at: block-height,
        verifier: tx-sender
      })
    )
    (ok true)
  )
)

(define-public (update-capabilities (manufacturer-id uint) (production-capacity uint) (certifications (list 10 (string-ascii 50))))
  (let ((manufacturer (unwrap! (map-get? manufacturers { manufacturer-id: manufacturer-id }) ERR_NOT_FOUND))
        (capabilities (unwrap! (map-get? manufacturer-capabilities { manufacturer-id: manufacturer-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get address manufacturer)) ERR_UNAUTHORIZED)

    (map-set manufacturer-capabilities
      { manufacturer-id: manufacturer-id }
      (merge capabilities {
        production-capacity: production-capacity,
        quality-certifications: certifications
      })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-manufacturer (manufacturer-id uint))
  (map-get? manufacturers { manufacturer-id: manufacturer-id })
)

(define-read-only (get-manufacturer-capabilities (manufacturer-id uint))
  (map-get? manufacturer-capabilities { manufacturer-id: manufacturer-id })
)

(define-read-only (is-verified (manufacturer-id uint))
  (match (map-get? manufacturers { manufacturer-id: manufacturer-id })
    manufacturer (is-eq (get verification-status manufacturer) "verified")
    false
  )
)
