#!/bin/bash

# Function to display help message
show_help() {
    echo "Usage: $0 POD_NAME [OPTIONS]"
    echo
    echo "Modify a pod by removing QoS class and job tracking annotations"
    echo
    echo "Options:"
    echo "  --help          Show this help message"
    echo "  -n, --namespace Specify the Kubernetes namespace (optional)"
    echo "  -c, --cluster   Specify the Kubernetes cluster (optional)"
    echo
    echo "Example:"
    echo "  $0 my-pod --namespace my-namespace --cluster my-cluster"
    exit 0
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl is not installed or not in PATH"
        exit 1
    fi
}

# Function to normalize pod name
normalize_pod_name() {
    local pod_name="$1"
    # Remove "pod/" prefix if present
    echo "${pod_name#pod/}"
}

# Initialize variables
POD_NAME=""
NAMESPACE=""
CLUSTER=""


# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -c|--cluster)
            CLUSTER="$2"
            shift 2
            ;;
        *)
            if [[ -z "$POD_NAME" ]]; then
                POD_NAME=$(normalize_pod_name "$1")
                shift
            else
                echo "Error: Unexpected argument: $1"
                echo "Use --help for usage information"
                exit 1
            fi
            ;;
    esac
done

# Check if POD_NAME is provided
if [[ -z "$POD_NAME" ]]; then
    echo "Error: Pod name is required"
    echo "Use --help for usage information"
    exit 1
fi

# Check for kubectl
check_kubectl

# Build the command with optional parameters
GET_CMD="kubectl get pod/$POD_NAME"
REPLACE_CMD="kubectl replace"

if [[ -n "$NAMESPACE" ]]; then
    GET_CMD="$GET_CMD -n $NAMESPACE"
    REPLACE_CMD="$REPLACE_CMD -n $NAMESPACE"
fi

if [[ -n "$CLUSTER" ]]; then
    GET_CMD="$GET_CMD --cluster $CLUSTER"
    REPLACE_CMD="$REPLACE_CMD --cluster $CLUSTER"
fi

# Add output format to GET_CMD
GET_CMD="$GET_CMD -o yaml"

# Execute the combined command
echo "Modifying pod: $POD_NAME"
$GET_CMD | grep -E -v "qosClass:|- batch.kubernetes.io/job-tracking" | $REPLACE_CMD -f -

# Check the exit status
if [[ $? -eq 0 ]]; then
    echo "Pod successfully modified"
else
    echo "Error: Failed to modify pod"
    exit 1
fi