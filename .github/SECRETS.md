# GitHub Secrets Configuration

This document outlines the required GitHub secrets for the CI/CD pipeline.

## Required Secrets

### Code Coverage (Optional)
- `CODECOV_TOKEN` - Token for uploading coverage reports to Codecov

### Android Signing (For Release Builds)
- `ANDROID_KEYSTORE_BASE64` - Base64 encoded Android keystore file
- `ANDROID_KEYSTORE_PASSWORD` - Password for the keystore
- `ANDROID_KEY_ALIAS` - Alias for the signing key
- `ANDROID_KEY_PASSWORD` - Password for the signing key

### iOS Signing (For Release Builds) 
- `BUILD_CERTIFICATE_BASE64` - Base64 encoded iOS signing certificate
- `P12_PASSWORD` - Password for the certificate
- `PROVISIONING_PROFILE_BASE64` - Base64 encoded provisioning profile

### API Keys for Testing (Optional)
- `TEST_GOOGLE_SPEECH_API_KEY` - Google Speech-to-Text API key for integration tests
- `TEST_OPENAI_API_KEY` - OpenAI API key for testing AI features

### Deployment (Optional)
- `STAGING_DEPLOY_KEY` - SSH key or token for staging deployment
- `AWS_ACCESS_KEY_ID` - AWS access key for S3 deployment
- `AWS_SECRET_ACCESS_KEY` - AWS secret key for S3 deployment

## Setting Up Secrets

1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and Variables → Actions
3. Click "New repository secret"
4. Add each secret with the appropriate name and value

## Environment-Specific Secrets

For the `staging` environment used in the deployment job:

1. Go to Settings → Environments
2. Create a new environment named `staging`
3. Add environment-specific secrets if needed

## Security Notes

- Never commit actual secret values to the repository
- Use GitHub's encrypted secrets feature for all sensitive data
- Rotate secrets regularly
- Use least-privilege access for API keys and tokens
- Consider using GitHub's OIDC for cloud provider authentication instead of long-lived tokens

## Optional Setup

The CI/CD pipeline is designed to work without secrets for basic functionality:
- Code analysis and formatting checks
- Unit and widget tests (without external API calls)
- Debug builds for all platforms
- Security scanning

Release builds and deployment will be skipped if the required secrets are not configured.