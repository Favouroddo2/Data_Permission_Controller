;; Data Access Rights Manager
;; A smart contract for managing granular data access permissions for apps and individuals

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-permission-denied (err u104))
(define-constant err-expired (err u105))
(define-constant err-already-exists (err u106))
(define-constant err-invalid-duration (err u107))
(define-constant err-resource-not-found (err u108))
(define-constant err-invalid-permission-level (err u109))

;; Permission levels
(define-constant permission-none u0)
(define-constant permission-read u1)
(define-constant permission-write u2)
(define-constant permission-admin u3)

;; Data Variables
(define-data-var next-resource-id uint u1)
(define-data-var next-permission-id uint u1)
(define-data-var default-access-duration uint u144) ;; ~24 hours in blocks
(define-data-var max-access-duration uint u52560) ;; ~1 year in blocks

;; Data Maps

;; Resource registry - defines what data resources exist
(define-map data-resources
    uint
    {
        id: uint,
        owner: principal,
        name: (string-ascii 100),
        description: (string-ascii 500),
        data-type: (string-ascii 50),
        sensitivity-level: uint, ;; 1=public, 2=internal, 3=confidential, 4=restricted
        created-at: uint,
        is-active: bool
    }
)

;; Access permissions - who can access what and how
(define-map access-permissions
    uint
    {
        id: uint,
        resource-id: uint,
        grantee: principal,
        grantor: principal,
        permission-level: uint,
        granted-at: uint,
        expires-at: (optional uint),
        is-revoked: bool,
        purpose: (string-ascii 200),
        conditions: (optional (string-ascii 300))
    }
)

;; Application registry - registered apps that can request access
(define-map registered-apps
    principal
    {
        name: (string-ascii 100),
        description: (string-ascii 500),
        developer: principal,
        verification-status: (string-ascii 20),
        registered-at: uint,
        is-active: bool
    }
)

;; Permission templates - predefined permission sets
(define-map permission-templates
    uint
    {
        id: uint,
        name: (string-ascii 50),
        description: (string-ascii 200),
        permission-level: uint,
        default-duration: uint,
        auto-approval: bool,
        created-by: principal
    }
)

;; Access logs - audit trail of data access
(define-map access-logs
    { resource-id: uint, accessor: principal, timestamp: uint }
    {
        permission-id: uint,
        action: (string-ascii 20),
        ip-hash: (optional (buff 32)),
        user-agent-hash: (optional (buff 32))
    }
)

;; Quick lookups
(define-map resource-owner-lookup { resource-id: uint } principal)
(define-map user-resources { owner: principal, resource-id: uint } bool)
(define-map active-permissions { resource-id: uint, grantee: principal } uint)

;; Authorization Functions
(define-private (is-contract-owner)
    (is-eq tx-sender contract-owner)
)

(define-private (is-resource-owner (resource-id uint))
    (match (map-get? resource-owner-lookup { resource-id: resource-id })
        owner (is-eq tx-sender owner)
        false
    )
)

(define-private (has-admin-access (resource-id uint))
    (let
        (
            (permission-id (default-to u0 (map-get? active-permissions { resource-id: resource-id, grantee: tx-sender })))
        )
        (if (> permission-id u0)
            (match (map-get? access-permissions permission-id)
                permission (and
                    (not (get is-revoked permission))
                    (>= (get permission-level permission) permission-admin)
                    (or 
                        (is-none (get expires-at permission))
                        (< stacks-block-height (unwrap! (get expires-at permission) false))
                    )
                )
                false
            )
            (is-resource-owner resource-id)
        )
    )
)

;; Resource Management Functions
(define-public (register-data-resource
    (name (string-ascii 100))
    (description (string-ascii 500))
    (data-type (string-ascii 50))
    (sensitivity-level uint))
    (let
        (
            (resource-id (var-get next-resource-id))
        )
        (asserts! (and (>= sensitivity-level u1) (<= sensitivity-level u4)) err-invalid-input)
        (asserts! (> (len name) u0) err-invalid-input)
        
        (map-set data-resources resource-id {
            id: resource-id,
            owner: tx-sender,
            name: name,
            description: description,
            data-type: data-type,
            sensitivity-level: sensitivity-level,
            created-at: stacks-block-height,
            is-active: true
        })
        
        (map-set resource-owner-lookup { resource-id: resource-id } tx-sender)
        (map-set user-resources { owner: tx-sender, resource-id: resource-id } true)
        
        (var-set next-resource-id (+ resource-id u1))
        (ok resource-id)
    )
)

(define-public (update-resource-info
    (resource-id uint)
    (name (string-ascii 100))
    (description (string-ascii 500))
    (sensitivity-level uint))
    (let
        (
            (resource (unwrap! (map-get? data-resources resource-id) err-not-found))
        )
        (asserts! (is-resource-owner resource-id) err-unauthorized)
        (asserts! (and (>= sensitivity-level u1) (<= sensitivity-level u4)) err-invalid-input)
        (asserts! (get is-active resource) err-not-found)
        
        (map-set data-resources resource-id (merge resource {
            name: name,
            description: description,
            sensitivity-level: sensitivity-level
        }))
        
        (ok true)
    )
)

(define-public (deactivate-resource (resource-id uint))
    (let
        (
            (resource (unwrap! (map-get? data-resources resource-id) err-not-found))
        )
        (asserts! (is-resource-owner resource-id) err-unauthorized)
        
        (map-set data-resources resource-id (merge resource { is-active: false }))
        (ok true)
    )
)

;; Permission Management Functions
(define-public (grant-access-permission
    (resource-id uint)
    (grantee principal)
    (permission-level uint)
    (duration-blocks (optional uint))
    (purpose (string-ascii 200))
    (conditions (optional (string-ascii 300))))
    (let
        (
            (resource (unwrap! (map-get? data-resources resource-id) err-resource-not-found))
            (permission-id (var-get next-permission-id))
            (expires-at (match duration-blocks
                blocks (some (+ stacks-block-height blocks))
                none
            ))
        )
        (asserts! (has-admin-access resource-id) err-unauthorized)
        (asserts! (get is-active resource) err-resource-not-found)
        (asserts! (and (>= permission-level permission-read) (<= permission-level permission-admin)) err-invalid-permission-level)
        (asserts! (match duration-blocks
            blocks (<= blocks (var-get max-access-duration))
            true
        ) err-invalid-duration)
        
        ;; Check if permission already exists and revoke it
        (match (map-get? active-permissions { resource-id: resource-id, grantee: grantee })
            existing-id (try! (revoke-access-permission resource-id grantee))
            true
        )
        
        (map-set access-permissions permission-id {
            id: permission-id,
            resource-id: resource-id,
            grantee: grantee,
            grantor: tx-sender,
            permission-level: permission-level,
            granted-at: stacks-block-height,
            expires-at: expires-at,
            is-revoked: false,
            purpose: purpose,
            conditions: conditions
        })
        
        (map-set active-permissions { resource-id: resource-id, grantee: grantee } permission-id)
        
        (var-set next-permission-id (+ permission-id u1))
        (ok permission-id)
    )
)

(define-public (revoke-access-permission (resource-id uint) (grantee principal))
    (let
        (
            (permission-id (unwrap! (map-get? active-permissions { resource-id: resource-id, grantee: grantee }) err-not-found))
            (permission (unwrap! (map-get? access-permissions permission-id) err-not-found))
        )
        (asserts! (has-admin-access resource-id) err-unauthorized)
        
        (map-set access-permissions permission-id (merge permission { is-revoked: true }))
        (map-delete active-permissions { resource-id: resource-id, grantee: grantee })
        
        (ok true)
    )
)

(define-public (extend-access-permission
    (resource-id uint)
    (grantee principal)
    (additional-blocks uint))
    (let
        (
            (permission-id (unwrap! (map-get? active-permissions { resource-id: resource-id, grantee: grantee }) err-not-found))
            (permission (unwrap! (map-get? access-permissions permission-id) err-not-found))
            (current-expiry (get expires-at permission))
        )
        (asserts! (has-admin-access resource-id) err-unauthorized)
        (asserts! (not (get is-revoked permission)) err-not-found)
        (asserts! (<= additional-blocks (var-get max-access-duration)) err-invalid-duration)
        
        (let
            (
                (new-expiry (match current-expiry
                    expiry (some (+ expiry additional-blocks))
                    (some (+ stacks-block-height additional-blocks))
                ))
            )
            (map-set access-permissions permission-id (merge permission { expires-at: new-expiry }))
            (ok true)
        )
    )
)

;; Application Registration
(define-public (register-application
    (app-principal principal)
    (name (string-ascii 100))
    (description (string-ascii 500)))
    (begin
        (asserts! (is-none (map-get? registered-apps app-principal)) err-already-exists)
        (asserts! (> (len name) u0) err-invalid-input)
        
        (map-set registered-apps app-principal {
            name: name,
            description: description,
            developer: tx-sender,
            verification-status: "pending",
            registered-at: stacks-block-height,
            is-active: true
        })
        
        (ok true)
    )
)

(define-public (verify-application (app-principal principal) (verified bool))
    (let
        (
            (app (unwrap! (map-get? registered-apps app-principal) err-not-found))
        )
        (asserts! (is-contract-owner) err-owner-only)
        
        (map-set registered-apps app-principal (merge app {
            verification-status: (if verified "verified" "rejected")
        }))
        
        (ok true)
    )
)

;; Data Access Functions
(define-public (request-data-access
    (resource-id uint)
    (requested-permission uint)
    (purpose (string-ascii 200)))
    (let
        (
            (resource (unwrap! (map-get? data-resources resource-id) err-resource-not-found))
        )
        (asserts! (get is-active resource) err-resource-not-found)
        (asserts! (and (>= requested-permission permission-read) (<= requested-permission permission-write)) err-invalid-permission-level)
        
        ;; For now, this creates a pending request event
        ;; In a full implementation, this would create a pending request that resource owners can approve
        (print {
            event: "access-requested",
            resource-id: resource-id,
            requester: tx-sender,
            permission-level: requested-permission,
            purpose: purpose,
            timestamp: stacks-block-height
        })
        
        (ok true)
    )
)

(define-public (access-data (resource-id uint) (action (string-ascii 20)))
    (let
        (
            (permission-id (unwrap! (map-get? active-permissions { resource-id: resource-id, grantee: tx-sender }) err-permission-denied))
            (permission (unwrap! (map-get? access-permissions permission-id) err-permission-denied))
            (resource (unwrap! (map-get? data-resources resource-id) err-resource-not-found))
        )
        (asserts! (get is-active resource) err-resource-not-found)
        (asserts! (not (get is-revoked permission)) err-permission-denied)
        
        ;; Check if permission has expired
        (asserts! (match (get expires-at permission)
            expiry (< stacks-block-height expiry)
            true
        ) err-expired)
        
        ;; Check permission level for action
        (asserts! (if (is-eq action "read")
            (>= (get permission-level permission) permission-read)
            (if (is-eq action "write")
                (>= (get permission-level permission) permission-write)
                (>= (get permission-level permission) permission-admin)
            )
        ) err-permission-denied)
        
        ;; Log the access
        (map-set access-logs 
            { resource-id: resource-id, accessor: tx-sender, timestamp: stacks-block-height }
            {
                permission-id: permission-id,
                action: action,
                ip-hash: none,
                user-agent-hash: none
            }
        )
        
        (print {
            event: "data-accessed",
            resource-id: resource-id,
            accessor: tx-sender,
            action: action,
            timestamp: stacks-block-height
        })
        
        (ok true)
    )
)

;; Permission Templates
(define-public (create-permission-template
    (name (string-ascii 50))
    (description (string-ascii 200))
    (permission-level uint)
    (default-duration uint)
    (auto-approval bool))
    (let
        (
            (template-id (var-get next-permission-id))
        )
        (asserts! (and (>= permission-level permission-read) (<= permission-level permission-write)) err-invalid-permission-level)
        (asserts! (<= default-duration (var-get max-access-duration)) err-invalid-duration)
        
        (map-set permission-templates template-id {
            id: template-id,
            name: name,
            description: description,
            permission-level: permission-level,
            default-duration: default-duration,
            auto-approval: auto-approval,
            created-by: tx-sender
        })
        
        (var-set next-permission-id (+ template-id u1))
        (ok template-id)
    )
)

;; Read-only Functions
(define-read-only (get-resource (resource-id uint))
    (map-get? data-resources resource-id)
)

(define-read-only (get-permission (permission-id uint))
    (map-get? access-permissions permission-id)
)

(define-read-only (get-active-permission (resource-id uint) (grantee principal))
    (match (map-get? active-permissions { resource-id: resource-id, grantee: grantee })
        permission-id (map-get? access-permissions permission-id)
        none
    )
)

(define-read-only (check-access-permission (resource-id uint) (grantee principal) (required-level uint))
    (match (get-active-permission resource-id grantee)
        permission (and
            (not (get is-revoked permission))
            (>= (get permission-level permission) required-level)
            (match (get expires-at permission)
                expiry (< stacks-block-height expiry)
                true
            )
        )
        false
    )
)

(define-read-only (get-registered-app (app-principal principal))
    (map-get? registered-apps app-principal)
)

(define-read-only (get-permission-template (template-id uint))
    (map-get? permission-templates template-id)
)

(define-read-only (get-access-log (resource-id uint) (accessor principal) (timestamp uint))
    (map-get? access-logs { resource-id: resource-id, accessor: accessor, timestamp: timestamp })
)

(define-read-only (is-resource-active (resource-id uint))
    (match (map-get? data-resources resource-id)
        resource (get is-active resource)
        false
    )
)

(define-read-only (get-user-permissions (user principal))
    ;; This would return a list of permissions for a user
    ;; Implementation would require iterating through permissions
    (ok user)
)

;; Administrative Functions
(define-public (set-default-access-duration (new-duration uint))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (asserts! (<= new-duration (var-get max-access-duration)) err-invalid-duration)
        (var-set default-access-duration new-duration)
        (ok true)
    )
)

(define-public (set-max-access-duration (new-max-duration uint))
    (begin
        (asserts! (is-contract-owner) err-owner-only)
        (var-set max-access-duration new-max-duration)
        (ok true)
    )
)

(define-public (emergency-revoke-all-permissions (resource-id uint))
    (let
        (
            (resource (unwrap! (map-get? data-resources resource-id) err-resource-not-found))
        )
        (asserts! (or (is-contract-owner) (is-resource-owner resource-id)) err-unauthorized)
        
        ;; This would require iterating through all permissions for the resource
        ;; In a full implementation, this would revoke all active permissions
        (print {
            event: "emergency-revoke-all",
            resource-id: resource-id,
            revoked-by: tx-sender,
            timestamp: stacks-block-height
        })
        
        (ok true)
    )
)

;; Contract Configuration
(define-read-only (get-contract-info)
    {
        default-access-duration: (var-get default-access-duration),
        max-access-duration: (var-get max-access-duration),
        next-resource-id: (var-get next-resource-id),
        next-permission-id: (var-get next-permission-id),
        contract-owner: contract-owner
    }
)