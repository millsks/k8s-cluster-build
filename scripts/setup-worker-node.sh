#!/bin/bash
set -euo pipefail

################################################################################
# Kubernetes Worker Node Setup Script
# 
# This script automates the setup of a Kubernetes worker node on
# Ubuntu Server 24.04 LTS using kubeadm, containerd, and prepares
# the node to join an existing cluster.
#
# Usage:
#   sudo ./setup-worker-node.sh [options]
#
# Options:
#   --hostname HOSTNAME          Set the hostname (required)
#   --cluster-ip IP              Node IP on cluster network (required)
#   --cluster-cidr CIDR          Cluster network CIDR (default: 172.16.0.0/16)
#   --control-plane-ip IP        Control plane IP address (for join command)
#   --join-token TOKEN           Kubeadm join token (optional, can join later)
#   --join-ca-hash HASH          CA cert hash for join (optional)
#   --cluster-interface NAME     Wired cluster interface (default: enp5s0f0)
#   --wifi-interface NAME        Wi-Fi management interface (default: wlp6s0)
#   --wifi-ssid SSID             Wi-Fi SSID (default: WIFI-SSID)
#   --wifi-password PASSWORD     Wi-Fi password (default: WIFI_PASSWORD)
#   --skip-netplan               Skip netplan configuration
#   --skip-updates               Skip apt updates and upgrades
#   --skip-join                  Skip joining the cluster (prepare only)
#   --k8s-version VERSION        Kubernetes version (default: v1.30)
#   --cni-version VERSION        CNI plugins version (default: v1.3.0)
#   --enable-livepatch           Enable Ubuntu Livepatch (requires token)
#   --livepatch-token TOKEN      Ubuntu Pro token for Livepatch
#
# Example (prepare and join):
#   sudo ./setup-worker-node.sh \
#     --hostname huginn-k8s-wk01 \
#     --cluster-ip 172.16.0.20 \
#     --control-plane-ip 172.16.0.10 \
#     --join-token <token> \
#     --join-ca-hash sha256:<hash>
#
# Example (prepare only, join later):
#   sudo ./setup-worker-node.sh \
#     --hostname geri-k8s-wk01 \
#     --cluster-ip 172.16.0.22 \
#     --skip-join
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
HOSTNAME=""
CLUSTER_IP=""
CLUSTER_CIDR="172.16.0.0/16"
CONTROL_PLANE_IP=""
JOIN_TOKEN=""
JOIN_CA_HASH=""
CLUSTER_INTERFACE="enp5s0f0"
WIFI_INTERFACE="wlp6s0"
WIFI_SSID="WIFI-SSID"
WIFI_PASSWORD="WIFI_PASSWORD"
SKIP_NETPLAN=false
SKIP_UPDATES=false
SKIP_JOIN=false
K8S_VERSION="v1.30"
CNI_VERSION="v1.3.0"
ENABLE_LIVEPATCH=false
LIVEPATCH_TOKEN=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --cluster-ip)
            CLUSTER_IP="$2"
            shift 2
            ;;
        --cluster-cidr)
            CLUSTER_CIDR="$2"
            shift 2
            ;;
        --control-plane-ip)
            CONTROL_PLANE_IP="$2"
            shift 2
            ;;
        --join-token)
            JOIN_TOKEN="$2"
            shift 2
            ;;
        --join-ca-hash)
            JOIN_CA_HASH="$2"
            shift 2
            ;;
        --cluster-interface)
            CLUSTER_INTERFACE="$2"
            shift 2
            ;;
        --wifi-interface)
            WIFI_INTERFACE="$2"
            shift 2
            ;;
        --wifi-ssid)
            WIFI_SSID="$2"
            shift 2
            ;;
        --wifi-password)
            WIFI_PASSWORD="$2"
            shift 2
            ;;
        --skip-netplan)
            SKIP_NETPLAN=true
            shift
            ;;
        --skip-updates)
            SKIP_UPDATES=true
            shift
            ;;
        --skip-join)
            SKIP_JOIN=true
            shift
            ;;
        --k8s-version)
            K8S_VERSION="$2"
            shift 2
            ;;
        --cni-version)
            CNI_VERSION="$2"
            shift 2
            ;;
        --enable-livepatch)
            ENABLE_LIVEPATCH=true
            shift
            ;;
        --livepatch-token)
            LIVEPATCH_TOKEN="$2"
            ENABLE_LIVEPATCH=true
            shift 2
            ;;
        -h|--help)
            grep "^#" "$0" | grep -v "#!/bin/bash" | sed 's/^# //'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validation
if [[ -z "$HOSTNAME" ]]; then
    echo -e "${RED}Error: --hostname is required${NC}"
    exit 1
fi

if [[ -z "$CLUSTER_IP" ]]; then
    echo -e "${RED}Error: --cluster-ip is required${NC}"
    exit 1
fi

if [[ "$ENABLE_LIVEPATCH" == true ]] && [[ -z "$LIVEPATCH_TOKEN" ]]; then
    echo -e "${RED}Error: --livepatch-token is required when --enable-livepatch is specified${NC}"
    exit 1
fi

if [[ "$SKIP_JOIN" == false ]]; then
    if [[ -z "$CONTROL_PLANE_IP" ]] || [[ -z "$JOIN_TOKEN" ]] || [[ -z "$JOIN_CA_HASH" ]]; then
        echo -e "${YELLOW}Warning: Missing join parameters. Use --skip-join to prepare node only.${NC}"
        echo -e "${YELLOW}Required for joining: --control-plane-ip, --join-token, --join-ca-hash${NC}"
        SKIP_JOIN=true
    fi
fi

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

enable_livepatch() {
    if ! command -v pro &> /dev/null; then
        log_info "Installing ubuntu-advantage-tools"
        apt install -y ubuntu-advantage-tools
    fi
    
    # Check if already attached
    if pro status | grep -q "esm-infra: enabled"; then
        log_info "Ubuntu Pro already attached"
    else
        log_info "Attaching Ubuntu Pro subscription"
        pro attach "$LIVEPATCH_TOKEN"
    fi
    
    # Enable livepatch
    log_info "Enabling Livepatch"
    pro enable livepatch
    
    # Verify livepatch status
    if canonical-livepatch status | grep -q "running"; then
        log_info "Livepatch is running successfully"
        canonical-livepatch status
    else
        log_warn "Livepatch may not be running correctly"
        canonical-livepatch status
    fi
}

# Main script
main() {
    check_root
    
    log_info "Starting Kubernetes worker node setup"
    log_info "Hostname: $HOSTNAME"
    log_info "Cluster IP: $CLUSTER_IP"
    
    # Step 1: Set hostname
    log_info "Step 1: Setting hostname to $HOSTNAME"
    hostnamectl set-hostname "$HOSTNAME"
    
    # Step 2: Configure netplan
    if [[ "$SKIP_NETPLAN" == false ]]; then
        log_info "Step 2: Configuring netplan"
        configure_netplan
    else
        log_warn "Skipping netplan configuration"
    fi
    
    # Step 3: Update system
    if [[ "$SKIP_UPDATES" == false ]]; then
        log_info "Step 3: Updating system packages"
        apt update
        DEBIAN_FRONTEND=noninteractive apt upgrade -y
    else
        log_warn "Skipping system updates"
    fi
    
    # Step 3a: Enable Livepatch (optional)
    if [[ "$ENABLE_LIVEPATCH" == true ]]; then
        log_info "Step 3a: Enabling Ubuntu Livepatch"
        enable_livepatch
    fi
    
    # Step 4: Install containerd
    log_info "Step 4: Installing and configuring containerd"
    install_containerd
    
    # Step 5: Configure system for Kubernetes
    log_info "Step 5: Configuring system (swap, kernel modules, sysctl)"
    configure_system
    
    # Step 6: Install CNI plugins
    log_info "Step 6: Installing CNI plugins"
    install_cni_plugins
    
    # Step 7: Install Kubernetes components
    log_info "Step 7: Installing kubeadm, kubelet, kubectl"
    install_kubernetes
    
    # Step 8: Pre-flight cleanup
    log_info "Step 8: Running pre-flight checks and cleanup"
    preflight_cleanup
    
    # Step 9: Join cluster (if requested)
    if [[ "$SKIP_JOIN" == false ]]; then
        log_info "Step 9: Joining Kubernetes cluster"
        join_cluster
        log_info "Worker node setup complete and joined to cluster!"
    else
        log_info "Worker node prepared successfully"
        log_info "To join the cluster later, run:"
        echo ""
        echo "sudo kubeadm join <control-plane-ip>:6443 --token <token> \\"
        echo "  --discovery-token-ca-cert-hash sha256:<hash>"
        echo ""
        log_info "Get the join command from the control plane by running:"
        echo "kubeadm token create --print-join-command"
    fi
}

configure_netplan() {
    local netplan_file="/etc/netplan/01-k8s-worker.yaml"
    
    # Backup existing netplan config
    if [[ -f "/etc/netplan/01-netcfg.yaml" ]]; then
        cp /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.backup
    fi
    
    # Create netplan configuration for worker node
    # Workers use multi-interface setup: Wi-Fi for internet, wired for cluster
    log_info "Configuring multi-interface setup (Wi-Fi + wired cluster network)"
    cat > "$netplan_file" <<EOF
network:
  version: 2

  wifis:
    $WIFI_INTERFACE:
      dhcp4: true
      access-points:
        "$WIFI_SSID":
          auth:
            key-management: "psk"
            password: "$WIFI_PASSWORD"

  ethernets:
    $CLUSTER_INTERFACE:
      dhcp4: no
      addresses:
        - $CLUSTER_IP/$(echo $CLUSTER_CIDR | cut -d'/' -f2)

EOF
    
    # Apply netplan
    netplan apply
    
    # Verify IP assignment
    sleep 3
    if ip addr show "$CLUSTER_INTERFACE" | grep -q "$CLUSTER_IP"; then
        log_info "IP $CLUSTER_IP successfully assigned to $CLUSTER_INTERFACE"
    else
        log_error "Failed to assign IP to $CLUSTER_INTERFACE"
        exit 1
    fi
    
    # Verify Wi-Fi connectivity
    log_info "Checking Wi-Fi connectivity..."
    sleep 5
    if ping -c 2 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_info "Internet connectivity via Wi-Fi confirmed"
    else
        log_warn "Wi-Fi connectivity check failed, continuing anyway"
    fi
}

install_containerd() {
    apt install -y containerd
    
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    
    # Enable systemd cgroups
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    systemctl enable --now containerd
    systemctl restart containerd
    
    if systemctl is-active --quiet containerd; then
        log_info "containerd is running"
    else
        log_error "containerd failed to start"
        exit 1
    fi
}

configure_system() {
    # Disable swap
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab
    
    # Load kernel modules
    cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
    
    modprobe overlay
    modprobe br_netfilter
    
    # Configure sysctl
    cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    
    sysctl --system
}

install_cni_plugins() {
    mkdir -p /opt/cni/bin
    
    log_info "Downloading CNI plugins ${CNI_VERSION}"
    curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz" | \
        tar -C /opt/cni/bin -xz
    
    # Verify installation
    if [[ -f "/opt/cni/bin/loopback" ]] && [[ -f "/opt/cni/bin/bridge" ]]; then
        log_info "CNI plugins installed successfully"
        ls -la /opt/cni/bin/
    else
        log_error "CNI plugins installation failed"
        exit 1
    fi
}

install_kubernetes() {
    apt install -y apt-transport-https curl gpg
    
    mkdir -p /etc/apt/keyrings
    
    # Add Kubernetes apt repository
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" | \
        gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | \
        tee /etc/apt/sources.list.d/kubernetes.list
    
    apt update
    apt install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    
    # Verify installation
    kubeadm version
    kubelet --version
    kubectl version --client
}

preflight_cleanup() {
    # Check for conflicting services
    if systemctl is-active --quiet snap.microk8s.daemon-kubelite; then
        log_warn "MicroK8s detected, removing..."
        snap remove microk8s
    fi
    
    # Check if this node was previously joined to a cluster
    if [[ -f "/etc/kubernetes/kubelet.conf" ]]; then
        log_warn "Previous cluster configuration detected. Running kubeadm reset..."
        kubeadm reset -f
        rm -rf /var/lib/kubelet /etc/kubernetes /etc/cni /var/lib/cni
        systemctl stop kubelet
        sleep 2
        systemctl start kubelet
    fi
    
    # Verify kubelet is running
    if systemctl is-active --quiet kubelet; then
        log_info "kubelet is running"
    else
        log_warn "kubelet is not running (this is normal before joining)"
    fi
}

join_cluster() {
    local join_cmd="kubeadm join ${CONTROL_PLANE_IP}:6443 --token ${JOIN_TOKEN} --discovery-token-ca-cert-hash ${JOIN_CA_HASH}"
    
    log_info "Joining cluster at ${CONTROL_PLANE_IP}:6443"
    log_info "Running: $join_cmd"
    
    $join_cmd
    
    if [[ $? -ne 0 ]]; then
        log_error "kubeadm join failed"
        log_error "Verify the token, CA hash, and control plane IP are correct"
        log_error "Generate a new join command on the control plane:"
        log_error "  kubeadm token create --print-join-command"
        exit 1
    fi
    
    log_info "Successfully joined cluster"
    log_info "Verify on control plane with: kubectl get nodes"
}

# Run main function
main
