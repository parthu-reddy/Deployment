#!/bin/bash

# Default values
MODE="prod"
SERVICES=()
ALL_SERVICES=("CustomerApplication" "PaymentGatewayIntegration" "MapsIntegration" "CommunicationIntegration")

# Help function
show_help() {
    echo "Usage: ./start.sh [OPTIONS] [SERVICES...]"
    echo ""
    echo "Options:"
    echo "  --mode <prod|debug>   Set the mode (default: prod)"
    echo "  --all                 Start all services"
    echo "  --help                Show this help message"
    echo ""
    echo "Available Services:"
    for svc in "${ALL_SERVICES[@]}"; do
        echo "  - $svc"
    done
    echo ""
    echo "Examples:"
    echo "  ./start.sh --all --mode debug"
    echo "  ./start.sh --mode prod CustomerApplication MapsIntegration"
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --mode) 
            MODE="$2"
            if [[ "$MODE" != "prod" && "$MODE" != "debug" ]]; then
                echo "Error: Mode must be 'prod' or 'debug'"
                exit 1
            fi
            shift 
            ;;
        --all) 
            SERVICES=("${ALL_SERVICES[@]}") 
            ;;
        --help)
            show_help
            exit 0
            ;;
        CustomerApplication|PaymentGatewayIntegration|MapsIntegration|CommunicationIntegration) 
            SERVICES+=("$1") 
            ;;
        *) 
            echo "Unknown parameter or service: $1"
            echo "Run ./start.sh --help for usage."
            exit 1 
            ;;
    esac
    shift
done

if [ ${#SERVICES[@]} -eq 0 ]; then
    echo "Error: No services selected."
    show_help
    exit 1
fi

# Ensure logs directory exists
LOG_DIR="$(pwd)/logs"
mkdir -p "$LOG_DIR"

echo "==========================================="
echo " Starting Services in $MODE mode"
echo "==========================================="

for SERVICE in "${SERVICES[@]}"; do
    echo "-> Starting $SERVICE..."
    
    # Navigate to service directory
    cd "../$SERVICE" || { echo "Failed to find directory for $SERVICE"; exit 1; }
    
    PROFILE_ARGS=""
    if [ "$MODE" == "debug" ]; then
        PROFILE_ARGS="-Dspring-boot.run.profiles=debug"
    fi
    
    # Run in background and capture PID
    ./mvnw spring-boot:run $PROFILE_ARGS > "$LOG_DIR/${SERVICE}.log" 2>&1 &
    PID=$!
    
    # Save PID to stop later
    echo $PID > "$LOG_DIR/${SERVICE}.pid"
    
    echo "   [OK] PID: $PID | Logs: deployments/logs/${SERVICE}.log"
    
    # Return to deployments directory
    cd - > /dev/null
done

echo "==========================================="
echo "All requested services have been started."
echo "Use './stop.sh' to stop them."
echo "==========================================="
