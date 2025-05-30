;; SkillTradePlatform: Peer-to-Peer Skill Exchange Network
;; Version: 1.0.0
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-SERVICE-NOT-FOUND (err u2))
(define-constant ERR-ALREADY-LISTED (err u3))
(define-constant ERR-INVALID-STATUS (err u4))
(define-constant ERR-INVALID-HOURS (err u5))
(define-constant ERR-INVALID-CATEGORY (err u6))
(define-constant ERR-INVALID-LEVEL (err u7))
(define-constant ERR-INVALID-TITLE (err u8))
(define-constant ERR-INVALID-DESCRIPTION (err u9))
(define-constant ERR-EXCHANGE-NOT-FOUND (err u10))
(define-constant ERR-SELF-EXCHANGE (err u11))
(define-constant ERR-SERVICE-UNAVAILABLE (err u12))
(define-constant ERR-EXCHANGE-INVALID-STATUS (err u13))
(define-constant MIN-HOURS u1)

(define-data-var next-service-id uint u1)
(define-data-var next-exchange-id uint u1)

(define-map services
    uint
    {
        provider: principal,
        service-title: (string-utf8 50),
        description: (string-utf8 200),
        category: (string-utf8 15),
        expertise-level: (string-utf8 20),
        status: (string-utf8 15),
        hours-available: uint
    }
)

(define-map exchanges
    uint
    {
        requester: principal,
        provider: principal,
        requested-service-id: uint,
        offered-service-id: uint,
        status: (string-utf8 15)
    }
)

(define-private (validate-category (category (string-utf8 15)))
    (or 
        (is-eq category u"Programming")
        (is-eq category u"Design")
        (is-eq category u"Writing")
        (is-eq category u"Marketing")
        (is-eq category u"Consulting")
        (is-eq category u"Teaching")
    )
)

(define-private (validate-level (level (string-utf8 20)))
    (or 
        (is-eq level u"Beginner")
        (is-eq level u"Intermediate")
        (is-eq level u"Advanced")
        (is-eq level u"Expert")
        (is-eq level u"Professional")
    )
)

(define-private (validate-text-length (text (string-utf8 200)) (min-length uint) (max-length uint))
    (let 
        (
            (text-length (len text))
        )
        (and 
            (>= text-length min-length)
            (<= text-length max-length)
        )
    )
)

(define-public (list-service 
    (service-title (string-utf8 50))
    (description (string-utf8 200))
    (category (string-utf8 15))
    (expertise-level (string-utf8 20))
    (hours-available uint)
)
    (let
        (
            (service-id (var-get next-service-id))
        )
        (asserts! (validate-text-length service-title u3 u50) ERR-INVALID-TITLE)
        (asserts! (validate-text-length description u10 u200) ERR-INVALID-DESCRIPTION)
        (asserts! (>= hours-available MIN-HOURS) ERR-INVALID-HOURS)
        (asserts! (validate-category category) ERR-INVALID-CATEGORY)
        (asserts! (validate-level expertise-level) ERR-INVALID-LEVEL)
        
        (map-set services service-id {
            provider: tx-sender,
            service-title: service-title,
            description: description,
            category: category,
            expertise-level: expertise-level,
            status: u"available",
            hours-available: hours-available
        })
        (var-set next-service-id (+ service-id u1))
        (ok service-id)
    )
)

(define-public (delist-service (service-id uint))
    (let
        (
            (service (unwrap! (map-get? services service-id) ERR-SERVICE-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get provider service)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status service) u"available") ERR-INVALID-STATUS)
        (ok (map-set services service-id (merge service { status: u"delisted" })))
    )
)

(define-public (propose-exchange (requested-service-id uint) (offered-service-id uint))
    (let
        (
            (requested-service (unwrap! (map-get? services requested-service-id) ERR-SERVICE-NOT-FOUND))
            (offered-service (unwrap! (map-get? services offered-service-id) ERR-SERVICE-NOT-FOUND))
            (exchange-id (var-get next-exchange-id))
        )
        (asserts! (is-eq (get status requested-service) u"available") ERR-SERVICE-UNAVAILABLE)
        (asserts! (is-eq (get status offered-service) u"available") ERR-SERVICE-UNAVAILABLE)
        (asserts! (is-eq (get provider offered-service) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq tx-sender (get provider requested-service))) ERR-SELF-EXCHANGE)
        
        (map-set exchanges exchange-id {
            requester: tx-sender,
            provider: (get provider requested-service),
            requested-service-id: requested-service-id,
            offered-service-id: offered-service-id,
            status: u"pending"
        })
        
        (map-set services requested-service-id (merge requested-service { status: u"pending" }))
        (map-set services offered-service-id (merge offered-service { status: u"pending" }))
        
        (var-set next-exchange-id (+ exchange-id u1))
        (ok exchange-id)
    )
)

(define-public (accept-proposal (exchange-id uint))
    (let
        (
            (exchange (unwrap! (map-get? exchanges exchange-id) ERR-EXCHANGE-NOT-FOUND))
            (requested-service-id (get requested-service-id exchange))
            (offered-service-id (get offered-service-id exchange))
            (requested-service (unwrap! (map-get? services requested-service-id) ERR-SERVICE-NOT-FOUND))
            (offered-service (unwrap! (map-get? services offered-service-id) ERR-SERVICE-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get provider exchange)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status exchange) u"pending") ERR-EXCHANGE-INVALID-STATUS)
        
        (map-set exchanges exchange-id (merge exchange { status: u"completed" }))
        (map-set services requested-service-id (merge requested-service { status: u"available" }))
        (map-set services offered-service-id (merge offered-service { status: u"available" }))
        
        (ok true)
    )
)

(define-public (decline-proposal (exchange-id uint))
    (let
        (
            (exchange (unwrap! (map-get? exchanges exchange-id) ERR-EXCHANGE-NOT-FOUND))
            (requested-service-id (get requested-service-id exchange))
            (offered-service-id (get offered-service-id exchange))
            (requested-service (unwrap! (map-get? services requested-service-id) ERR-SERVICE-NOT-FOUND))
            (offered-service (unwrap! (map-get? services offered-service-id) ERR-SERVICE-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get provider exchange)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status exchange) u"pending") ERR-EXCHANGE-INVALID-STATUS)
        
        (map-set exchanges exchange-id (merge exchange { status: u"declined" }))
        (map-set services requested-service-id (merge requested-service { status: u"available" }))
        (map-set services offered-service-id (merge offered-service { status: u"available" }))
        
        (ok true)
    )
)

(define-public (cancel-proposal (exchange-id uint))
    (let
        (
            (exchange (unwrap! (map-get? exchanges exchange-id) ERR-EXCHANGE-NOT-FOUND))
            (requested-service-id (get requested-service-id exchange))
            (offered-service-id (get offered-service-id exchange))
            (requested-service (unwrap! (map-get? services requested-service-id) ERR-SERVICE-NOT-FOUND))
            (offered-service (unwrap! (map-get? services offered-service-id) ERR-SERVICE-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get requester exchange)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status exchange) u"pending") ERR-EXCHANGE-INVALID-STATUS)
        
        (map-set exchanges exchange-id (merge exchange { status: u"cancelled" }))
        (map-set services requested-service-id (merge requested-service { status: u"available" }))
        (map-set services offered-service-id (merge offered-service { status: u"available" }))
        
        (ok true)
    )
)

(define-read-only (get-service (service-id uint))
    (ok (map-get? services service-id))
)

(define-read-only (get-provider (service-id uint))
    (ok (get provider (unwrap! (map-get? services service-id) ERR-SERVICE-NOT-FOUND)))
)

(define-read-only (get-exchange (exchange-id uint))
    (ok (map-get? exchanges exchange-id))
)
