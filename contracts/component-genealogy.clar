;; Component Genealogy Contract
;; Tracks product component history and relationships

(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_COMPONENT_EXISTS (err u201))
(define-constant ERR_COMPONENT_NOT_FOUND (err u202))
(define-constant ERR_INVALID_RELATIONSHIP (err u203))

;; Component data structure
(define-map components
  { component-id: (string-ascii 64) }
  {
    supplier: principal,
    component-type: (string-ascii 64),
    material: (string-ascii 64),
    origin-country: (string-ascii 32),
    manufacture-date: uint,
    batch-number: (string-ascii 64),
    created-at: uint
  }
)

;; Component relationships (parent -> child)
(define-map component-relationships
  { parent-id: (string-ascii 64), child-id: (string-ascii 64) }
  {
    relationship-type: (string-ascii 32),
    quantity: uint,
    assembly-date: uint,
    assembler: principal
  }
)

;; Component usage in products
(define-map product-components
  { product-id: (string-ascii 64), component-id: (string-ascii 64) }
  {
    quantity-used: uint,
    integration-date: uint,
    integrator: principal
  }
)

;; Register a new component
(define-public (register-component
  (component-id (string-ascii 64))
  (component-type (string-ascii 64))
  (material (string-ascii 64))
  (origin-country (string-ascii 32))
  (batch-number (string-ascii 64)))
  (begin
    (asserts! (is-none (map-get? components { component-id: component-id })) ERR_COMPONENT_EXISTS)
    (asserts! (> (len component-id) u0) ERR_UNAUTHORIZED)

    (map-set components
      { component-id: component-id }
      {
        supplier: tx-sender,
        component-type: component-type,
        material: material,
        origin-country: origin-country,
        manufacture-date: block-height,
        batch-number: batch-number,
        created-at: block-height
      }
    )
    (ok true)
  )
)

;; Add component relationship
(define-public (add-component-relationship
  (parent-id (string-ascii 64))
  (child-id (string-ascii 64))
  (relationship-type (string-ascii 32))
  (quantity uint))
  (begin
    (asserts! (is-some (map-get? components { component-id: parent-id })) ERR_COMPONENT_NOT_FOUND)
    (asserts! (is-some (map-get? components { component-id: child-id })) ERR_COMPONENT_NOT_FOUND)
    (asserts! (not (is-eq parent-id child-id)) ERR_INVALID_RELATIONSHIP)

    (map-set component-relationships
      { parent-id: parent-id, child-id: child-id }
      {
        relationship-type: relationship-type,
        quantity: quantity,
        assembly-date: block-height,
        assembler: tx-sender
      }
    )
    (ok true)
  )
)

;; Link component to product
(define-public (link-component-to-product
  (product-id (string-ascii 64))
  (component-id (string-ascii 64))
  (quantity-used uint))
  (begin
    (asserts! (is-some (map-get? components { component-id: component-id })) ERR_COMPONENT_NOT_FOUND)
    (asserts! (> quantity-used u0) ERR_UNAUTHORIZED)

    (map-set product-components
      { product-id: product-id, component-id: component-id }
      {
        quantity-used: quantity-used,
        integration-date: block-height,
        integrator: tx-sender
      }
    )
    (ok true)
  )
)

;; Get component details
(define-read-only (get-component (component-id (string-ascii 64)))
  (map-get? components { component-id: component-id })
)

;; Get component relationship
(define-read-only (get-component-relationship (parent-id (string-ascii 64)) (child-id (string-ascii 64)))
  (map-get? component-relationships { parent-id: parent-id, child-id: child-id })
)

;; Get product component link
(define-read-only (get-product-component (product-id (string-ascii 64)) (component-id (string-ascii 64)))
  (map-get? product-components { product-id: product-id, component-id: component-id })
)
