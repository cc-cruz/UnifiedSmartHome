# Yale Lock Adapter

The Yale Lock Adapter provides secure integration with Yale smart locks through their API. This adapter implements comprehensive security measures to ensure safe communication and operation of Yale locks.

## Security Features

### 1. Certificate Pinning
- Implements certificate pinning to prevent man-in-the-middle attacks
- Validates server certificates against pinned certificates in the app bundle
- Automatically rejects connections with invalid certificates

### 2. Secure Credential Storage
- Stores sensitive credentials in the iOS Keychain
- Implements proper access control with user presence requirement
- Uses secure keychain attributes for credential protection

### 3. Input Validation
- Validates all input parameters before API calls
- Implements strict format checking for lock IDs
- Validates operation parameters within safe ranges

### 4. State Verification
- Verifies lock state after operations
- Implements retry logic with exponential backoff
- Ensures operations complete successfully

### 5. Rate Limiting
- Implements request rate limiting (500ms between requests)
- Prevents API abuse and potential DoS attacks
- Maintains optimal performance while ensuring security

### 6. Audit Logging
- Comprehensive logging of all lock operations
- Tracks operation status and outcomes
- Sanitizes sensitive information in logs

## Setup Instructions

### 1. Environment Variables
Set the following environment variables in your app's configuration:

```bash
YALE_API_KEY=your_api_key
YALE_BASE_URL=https://api.yalehome.com/v1
YALE_CLIENT_ID=your_client_id
YALE_CLIENT_SECRET=your_client_secret
```

### 2. Certificate Setup
1. Obtain the Yale API certificates
2. Add the certificates to your app bundle with the following names:
   - `yale-home-cert-1.cer`
   - `yale-home-cert-2.cer`

### 3. Usage Example

```swift
// Initialize the adapter
let adapter = YaleLockAdapter()

// Initialize with authentication token
try adapter.initialize(with: "your_auth_token")

// Fetch available locks
let locks = try await adapter.fetchLocks()

// Control a lock
try await adapter.controlLock(id: "lock_id", operation: .lock)
```

## Error Handling

The adapter provides detailed error handling for various scenarios:

- `LockOperationError.invalidLockId`: Invalid lock ID format
- `LockOperationError.invalidBatteryThreshold`: Invalid battery threshold value
- `LockOperationError.invalidAutoLockDelay`: Invalid auto-lock delay value
- `LockOperationError.stateVerificationFailed`: Lock state verification failed
- `AuthenticationError`: Various authentication-related errors

## Best Practices

1. Always use HTTPS for API communication
2. Regularly rotate API keys and credentials
3. Monitor audit logs for suspicious activity
4. Keep certificates up to date
5. Implement proper error handling in your application

## Testing

The adapter includes comprehensive unit tests covering:
- Initialization
- Lock operations
- Security features
- Error handling
- Rate limiting
- Certificate validation

Run the tests using:
```bash
swift test
```

## Security Considerations

1. **API Key Protection**
   - Never commit API keys to source control
   - Use environment variables or secure configuration management
   - Rotate keys regularly

2. **Credential Storage**
   - Credentials are stored securely in the Keychain
   - Access requires user presence
   - Credentials are cleared on logout

3. **Network Security**
   - All communication is encrypted
   - Certificate pinning prevents MITM attacks
   - Rate limiting prevents abuse

4. **Input Security**
   - All inputs are validated
   - Sensitive data is sanitized in logs
   - Operation parameters are range-checked

## Support

For issues or questions, please contact the development team or refer to the Yale API documentation. 