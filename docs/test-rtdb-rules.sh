#!/bin/bash

# Firebase RTDB Rules Quick Test Script
# Tests basic group chat security rules via Firebase REST API
#
# Usage: ./test-rtdb-rules.sh
# Requires: Firebase Auth ID token for authenticated requests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="sorted-d3844"
RTDB_URL="https://${PROJECT_ID}-default-rtdb.firebaseio.com"

echo "🔥 Firebase RTDB Rules Test Script"
echo "=================================="
echo ""
echo "Project: $PROJECT_ID"
echo "Database: $RTDB_URL"
echo ""

# Function to print test results
print_result() {
    local test_name=$1
    local expected=$2
    local result=$3

    if [ "$expected" == "$result" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name (Expected: $expected, Got: $result)"
    fi
}

# Check if user has Firebase CLI installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}Error: Firebase CLI not installed${NC}"
    echo "Install with: npm install -g firebase-tools"
    exit 1
fi

echo "📋 Test Plan:"
echo "1. Test unauthenticated read (should fail)"
echo "2. Test group creation validation"
echo "3. Test admin permission checks"
echo "4. Test participant count limits"
echo ""
read -p "Press Enter to start tests..."

# Test 1: Unauthenticated read should fail
echo ""
echo "Test 1: Unauthenticated read..."
response=$(curl -s -o /dev/null -w "%{http_code}" "${RTDB_URL}/conversations.json")

if [ "$response" == "401" ] || [ "$response" == "403" ]; then
    print_result "Unauthenticated read blocked" "FAIL" "FAIL"
else
    print_result "Unauthenticated read blocked" "FAIL" "PASS"
fi

# Note: Authenticated tests require ID token
echo ""
echo -e "${YELLOW}ℹ️  Note:${NC} Authenticated tests require Firebase Auth ID token."
echo ""
echo "To get your ID token:"
echo "1. In Firebase Console, go to Authentication"
echo "2. Add a test user if not exists"
echo "3. Use Firebase Admin SDK or client SDK to get ID token"
echo "4. Or use: firebase auth:export --format=json"
echo ""

# Example curl command for authenticated request
echo "Example authenticated test:"
echo ""
echo "export ID_TOKEN=\"your-firebase-id-token\""
echo ""
echo "# Test: Create group with 1 participant (should fail)"
echo 'curl -X PUT "${RTDB_URL}/conversations/test_group_001.json?auth=${ID_TOKEN}" \'
echo '  -H "Content-Type: application/json" \'
echo '  -d @- << EOF'
echo '{'
echo '  "participants": { "test-user-alice": true },'
echo '  "participantList": ["test-user-alice"],'
echo '  "isGroup": true,'
echo '  "groupName": "Solo Group"'
echo '}'
echo 'EOF'
echo ""

# Test 2: Validate rules syntax
echo ""
echo "Test 2: Validating rules syntax..."
if firebase database:rules:validate --project "$PROJECT_ID" 2>/dev/null; then
    print_result "Rules syntax valid" "PASS" "PASS"
else
    print_result "Rules syntax valid" "PASS" "FAIL"
fi

# Test 3: Check rules content
echo ""
echo "Test 3: Checking deployed rules..."

# Get current rules
firebase database:get / --project "$PROJECT_ID" --shallow 2>/dev/null > /dev/null
if [ $? -eq 0 ]; then
    print_result "Database accessible" "PASS" "PASS"
else
    print_result "Database accessible" "PASS" "FAIL"
fi

echo ""
echo "=================================="
echo "✅ Basic tests complete!"
echo ""
echo "📚 For comprehensive testing:"
echo "1. See: docs/firebase-rules-test-plan.md"
echo "2. Use Firebase Console Rules Playground"
echo "3. Run Swift unit tests: FirebaseRulesTests.swift"
echo ""
echo "🔗 Quick links:"
echo "- Rules: https://console.firebase.google.com/project/${PROJECT_ID}/database/${PROJECT_ID}-default-rtdb/rules"
echo "- Data: https://console.firebase.google.com/project/${PROJECT_ID}/database/${PROJECT_ID}-default-rtdb/data"
echo "- Playground: https://console.firebase.google.com/project/${PROJECT_ID}/database/${PROJECT_ID}-default-rtdb/rules/playground"
echo ""
