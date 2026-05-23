package test

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// oidcFromEnv returns the OIDC provider ARN + URL pair from environment
// variables set by CI. These come from a pre-existing EKS cluster — the
// Velero module assumes the cluster's IRSA OIDC provider is already in place.
func oidcFromEnv(t *testing.T) (string, string) {
	arn := os.Getenv("TERRATEST_OIDC_PROVIDER_ARN")
	url := os.Getenv("TERRATEST_OIDC_PROVIDER_URL")
	require.NotEmpty(t, arn, "TERRATEST_OIDC_PROVIDER_ARN must be set")
	require.NotEmpty(t, url, "TERRATEST_OIDC_PROVIDER_URL must be set")
	return arn, url
}

// TestVeleroBackendDefaultApply is the canonical happy-path Terratest. It
// applies the module against an existing EKS OIDC provider, asserts the
// bucket and IAM role exist via direct AWS API calls, then destroys.
func TestVeleroBackendDefaultApply(t *testing.T) {
	t.Parallel()

	envName := fmt.Sprintf("ci-%s", random.UniqueId())
	region := "us-east-1"

	oidcArn, oidcURL := oidcFromEnv(t)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../plan",
		Vars: map[string]interface{}{
			"project":           "tt",
			"environment":       envName,
			"region":            region,
			"oidc_provider_arn": oidcArn,
			"oidc_provider_url": oidcURL,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	aws.AssertS3BucketExists(t, region, bucketName)
	aws.AssertS3BucketVersioningExists(t, region, bucketName)

	iamRoleArn := terraform.Output(t, terraformOptions, "iam_role_arn")
	assert.Contains(t, iamRoleArn, "arn:aws:iam:")

	kmsKeyArn := terraform.Output(t, terraformOptions, "kms_key_arn")
	assert.Contains(t, kmsKeyArn, "arn:aws:kms:")

	drBucket := terraform.Output(t, terraformOptions, "dr_bucket_name")
	assert.Empty(t, drBucket, "dr_bucket_name should be empty when DR is not enabled")
}

// TestVeleroBackendDREnabled exercises the cross-region replication path. It
// writes a test object to the primary bucket and waits for it to appear on
// the DR side, confirming replication actually replicates.
func TestVeleroBackendDREnabled(t *testing.T) {
	t.Parallel()

	envName := fmt.Sprintf("ci-%s", random.UniqueId())
	primaryRegion := "us-east-1"
	drRegion := "us-west-2"

	oidcArn, oidcURL := oidcFromEnv(t)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../plan",
		Vars: map[string]interface{}{
			"project":           "tt",
			"environment":       envName,
			"region":            primaryRegion,
			"dr_region":         drRegion,
			"oidc_provider_arn": oidcArn,
			"oidc_provider_url": oidcURL,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	primaryBucket := terraform.Output(t, terraformOptions, "bucket_name")
	drBucket := terraform.Output(t, terraformOptions, "dr_bucket_name")

	aws.AssertS3BucketExists(t, primaryRegion, primaryBucket)
	aws.AssertS3BucketExists(t, drRegion, drBucket)

	testKey := "terratest-replication-check.json"
	testBody := fmt.Sprintf(`{"timestamp":"%s"}`, time.Now().UTC().Format(time.RFC3339))
	aws.PutS3ObjectContents(t, primaryRegion, primaryBucket, testKey, testBody)

	// S3 replication is async (usually under 30s but can take longer).
	retry.DoWithRetry(t, "Wait for replication", 30, 10*time.Second, func() (string, error) {
		body, err := aws.GetS3ObjectContentsE(t, drRegion, drBucket, testKey)
		if err != nil {
			return "", fmt.Errorf("not yet replicated: %w", err)
		}
		if body != testBody {
			return "", fmt.Errorf("replicated body does not match: got %q", body)
		}
		return body, nil
	})
}
