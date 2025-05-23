# Data Access Rights Manager

A comprehensive smart contract system for managing granular data access permissions on the Stacks blockchain. This contract enables secure, auditable, and fine-grained control over data resource access for applications and individuals.

## Overview

The Data Access Rights Manager provides a decentralized solution for managing data permissions with enterprise-grade features including:

- **Granular Permission Control**: Read, write, and admin access levels
- **Temporal Access Management**: Time-based permissions with expiration
- **Resource Classification**: Multiple sensitivity levels for different data types
- **Application Registry**: Verified app ecosystem for trusted data access
- **Audit Trail**: Complete access logging for compliance and security
- **Permission Templates**: Standardized access patterns for common use cases

## Features

### Core Functionality

- **Data Resource Management**: Register and manage data resources with metadata
- **Permission Granting**: Grant fine-grained access permissions to users and applications
- **Access Control**: Enforce permission-based access with automatic expiration
- **Application Registry**: Register and verify applications for trusted access
- **Audit Logging**: Track all data access events for security and compliance

### Permission Levels

- **None (0)**: No access
- **Read (1)**: Read-only access to data
- **Write (2)**: Read and write access to data
- **Admin (3)**: Full administrative control including permission management

### Sensitivity Levels

- **Public (1)**: Publicly accessible data
- **Internal (2)**: Internal organization data
- **Confidential (3)**: Sensitive business data
- **Restricted (4)**: Highly sensitive, regulated data

## Getting Started

### Prerequisites

- Stacks blockchain node or access to a Stacks testnet/mainnet
- Clarity smart contract development environment
- Understanding of Stacks and Clarity programming

### Deployment

1. Deploy the contract to the Stacks blockchain
2. The deploying address becomes the contract owner with administrative privileges
3. Configure default settings using administrative functions

### Basic Usage

#### 1. Register a Data Resource

```clarity
(contract-call? .data-access-manager register-data-resource
  "User Profile Data"
  "Personal user information including name, email, preferences"
  "profile"
  u2) ;; Internal sensitivity level
```

#### 2. Grant Access Permission

```clarity
(contract-call? .data-access-manager grant-access-permission
  u1              ;; resource-id
  'SP123...       ;; grantee principal
  u1              ;; read permission
  (some u144)     ;; expires in ~24 hours
  "Analytics processing"
  none)           ;; no special conditions
```

#### 3. Access Data

```clarity
(contract-call? .data-access-manager access-data
  u1              ;; resource-id
  "read")         ;; action type
```

#### 4. Register an Application

```clarity
(contract-call? .data-access-manager register-application
  'SP456...       ;; app principal
  "Analytics Dashboard"
  "Business intelligence application for data visualization")
```

## Smart Contract Architecture

### Data Structures

#### Resource Registry
Stores metadata about data resources including ownership, type, and sensitivity level.

#### Access Permissions
Manages who can access what resources, with what permissions, and for how long.

#### Application Registry
Tracks registered applications and their verification status.

#### Permission Templates
Predefined permission sets for common access patterns.

#### Access Logs
Audit trail of all data access events.

### Key Functions

#### Resource Management
- `register-data-resource`: Create new data resources
- `update-resource-info`: Modify resource metadata
- `deactivate-resource`: Disable resource access

#### Permission Management
- `grant-access-permission`: Grant access to users/apps
- `revoke-access-permission`: Remove access permissions
- `extend-access-permission`: Extend permission duration

#### Data Access
- `request-data-access`: Request access to a resource
- `access-data`: Access data with permission validation

#### Application Management
- `register-application`: Register new applications
- `verify-application`: Admin function to verify apps

### Authorization Model

The contract implements a hierarchical authorization model:

1. **Contract Owner**: Full administrative control
2. **Resource Owner**: Control over their own resources
3. **Admin Permission Holders**: Can manage permissions for specific resources
4. **Regular Users**: Can access data based on granted permissions

## Security Features

### Access Control
- Multi-level permission system (read/write/admin)
- Time-based permission expiration
- Resource owner and admin-only operations
- Permission revocation capabilities

### Audit Trail
- Complete logging of data access events
- Immutable audit trail on blockchain
- Timestamp tracking for all operations
- Permission change history

### Data Protection
- Sensitivity level classification
- Resource deactivation capabilities
- Emergency permission revocation
- Granular condition-based access

## API Reference

### Public Functions

#### Resource Management
- `register-data-resource(name, description, data-type, sensitivity-level)`
- `update-resource-info(resource-id, name, description, sensitivity-level)`
- `deactivate-resource(resource-id)`

#### Permission Management
- `grant-access-permission(resource-id, grantee, permission-level, duration-blocks, purpose, conditions)`
- `revoke-access-permission(resource-id, grantee)`
- `extend-access-permission(resource-id, grantee, additional-blocks)`

#### Application Registry
- `register-application(app-principal, name, description)`
- `verify-application(app-principal, verified)` *(owner only)*

#### Data Access
- `request-data-access(resource-id, requested-permission, purpose)`
- `access-data(resource-id, action)`

#### Templates
- `create-permission-template(name, description, permission-level, default-duration, auto-approval)`

### Read-Only Functions

- `get-resource(resource-id)`: Get resource information
- `get-permission(permission-id)`: Get permission details
- `get-active-permission(resource-id, grantee)`: Check active permissions
- `check-access-permission(resource-id, grantee, required-level)`: Validate access
- `get-registered-app(app-principal)`: Get application info
- `get-contract-info()`: Get contract configuration

### Administrative Functions

- `set-default-access-duration(new-duration)`: Set default permission duration
- `set-max-access-duration(new-max-duration)`: Set maximum permission duration
- `emergency-revoke-all-permissions(resource-id)`: Emergency access revocation

## Error Codes

- `u100`: Owner only operation
- `u101`: Resource/permission not found
- `u102`: Unauthorized access
- `u103`: Invalid input parameters
- `u104`: Permission denied
- `u105`: Permission expired
- `u106`: Resource already exists
- `u107`: Invalid duration specified
- `u108`: Resource not found
- `u109`: Invalid permission level

## Use Cases

### Enterprise Data Management
- Employee access to internal systems
- Contractor temporary access
- Department-specific data sharing
- Compliance audit trails

### Application Ecosystem
- Third-party app data access
- API access management
- User consent management
- Developer verification

### Personal Data Control
- Individual data sovereignty
- Selective data sharing
- Privacy preference enforcement
- Access history tracking

## Best Practices

### For Resource Owners
1. Set appropriate sensitivity levels for your data
2. Use descriptive names and purposes for permissions
3. Regularly review and audit access permissions
4. Set reasonable expiration times for temporary access
5. Revoke permissions when no longer needed

### For Application Developers
1. Register your application for verification
2. Request minimal necessary permissions
3. Clearly state the purpose of data access
4. Respect permission expiration times
5. Implement proper error handling for access denials

### For System Administrators
1. Regularly verify new applications
2. Monitor access patterns for suspicious activity
3. Set appropriate default and maximum durations
4. Use emergency revocation judiciously
5. Maintain clear governance policies

## Contributing

This smart contract is designed to be extensible and can be enhanced with additional features:

- Advanced permission conditions
- Integration with external identity systems
- Automated compliance reporting
- Multi-signature approval workflows
- Cross-chain data access bridges

## License

This project is released under the MIT License. See LICENSE file for details.

## Support

For questions, issues, or contributions, please refer to the project documentation or contact the development team.

---

**Note**: This smart contract handles sensitive data access permissions. Always test thoroughly on testnets before deploying to mainnet, and consider security audits for production use.

**Note**: This smart contract handles sensitive data access permissions. Always test thoroughly on testnets before deploying to mainnet, and consider security audits for production use.