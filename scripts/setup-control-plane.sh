#!/bin/bash
set -euo pipefail

################################################################################
# Kubernetes Control Plane Setup Script
# 
# This script automates the setup of a Kubernetes control plane node on
# Ubuntu Server 24.04 LTS using kubeadm, containerd, and Flannel CNI.
#
# Usage:
#   sudo ./setup-control-plane.sh [options]
#
# Options:
#   --hostname HOSTNAME          Set the hostname (default: k8s-control)
#   --api-address IP             API server advertise address (required for multi-interface)
#   --cluster-ip IP              Node IP on cluster network (required)
#   --cluster-cidr CIDR          Cluster network CIDR (default: 172.16.0.0/16)
#   --pod-cidr CIDR              Pod network CIDR (default: 10.244.0.0/16)
#   --gateway IP                 Default gateway (optional, for Wi-Fi interface)
#   --dns-servers "IP1 IP2"      DNS servers (default: "1.1.1.1 8.8.8.8")
#   --cluster-interface NAME     Wired cluster interface (default: enp3s0)
#   --wifi-interface NAME        Wi-Fi management interface (optional)
#   --skip-netplan               Skip netplan configuration
#   --skip-updates               Skip apt updates and upgrades
#   --k8s-version VERSION        Kubernetes version (default: v1.30)
#   --cni-version VERSION        CNI plugins version (default: v1.3.0)
#
# Example (single interface):
#   sudo ./setup-control-plane.sh --hostname k8s-control --cluster-ip 192.168.1.10
#
# Example (multi-interface):
#   sudo ./setup-control-plane.sh \
#     --hostname k8s-control \
#     --api-address 172.16.0.10 \
#     --cluster-ip 172.16.0.10 \
#     --cluster-interface enp3s0 \
#     --wifi-interface wlp2s0
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
HOSTNAME="k8s-control"
API_ADDRESS=""
CLUSTER_IP=""
CLUSTER_CIDR="172.16.0.0/16"
POD_CIDR="10.244.0.0/16"
GATEWAY=""
DNS_SERVERS="1.1.1.1 8.8.8.8"
CLUSTER_INTERFACE="enp3s0"
WIFI_INTERFACE=""
SKIP_NETPLAN=false
SKIP_UPDATES=false
K8S_VERSION="v1.30"
CNI_VERSION="v1.3.0"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --api-address)
            API_ADDRESS="$2"
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
        --pod-cidr)
            POD_CIDR="$2"
            shift 2
            ;;
        --gateway)
            GATEWAY="$2"
            shift 2
            ;;
        --dns-servers)
            DNS_SERVERS="$2"
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
        --skip-netplan)
            SKIP_NETPLAN=true
            shift
            ;;
        --skip-updates)
            SKIP_UPDATES=true
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
if [[ -z "$CLUSTER_IP" ]]; then
    echo -e "${RED}Error: --cluster-ip is required${NC}"
    exit 1
fi

# If no API address specified, use cluster IP
if [[ -z "$API_ADDRESS" ]]; then
    API_ADDRESS="$CLUSTER_IP"
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

# Main script
main() {
    check_root
    
    log_info "Starting Kubernetes control plane setup"
    log_info "Hostname: $HOSTNAME"
    log_info "Cluster IP: $CLUSTER_IP"
    log_info "API Address: $API_ADDRESS"
    log_info "Pod CIDR: $POD_CIDR"
    
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
    
    # Step 9: Initialize control plane
    log_info "Step 9: Initializing Kubernetes control plane"
    initialize_control_plane
    
    # Step 10: Configure kubectl
    log_info "Step 10: Configuring kubectl for current user"
    configure_kubectl
    
    # Step 11: Install Flannel CNI
    log_info "Step 11: Installing Flannel CNI"
    install_flannel
    
    # Step 12: Wait for node to be ready
    log_info "Step 12: Waiting for control plane to be ready"
    wait_for_node_ready
    
    # Step 13: Generate join command
    log_info "Step 13: Generating worker node join command"
    generate_join_command
    
    log_info "Control plane setup complete!"
    log_info "Run 'kubectl get nodes' to verify the installation"
    log_info "Worker join command has been saved to /root/kubeadm-join-command.sh"
}

configure_netplan() {
    local netplan_file="/etc/netplan/01-k8s-cluster.yaml"
    
    # Backup existing netplan config
    if [[ -f "/etc/netplan/01-netcfg.yaml" ]]; then
        cp /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.backup
    fi
    
    # Create netplan configuration
    if [[ -n "$WIFI_INTERFACE" ]]; then
        # Multi-interface configuration
        log_info "Configuring multi-interface setup"
        cat > "$netplan_file" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $CLUSTER_INTERFACE:
      dhcp4: no
      addresses:
        - $CLUSTER_IP/$(echo $CLUSTER_CIDR | cut -d'/' -f2)
      # No gateway or nameservers - Wi-Fi handles internet
    $WIFI_INTERFACE:
      dhcp4: yes
EOF
    else
        # Single interface configuration
        log_info "Configuring single-interface setup"
        local dns_array=($(echo $DNS_SERVERS | tr ' ' '\n'))
        cat > "$netplan_file" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $CLUSTER_INTERFACE:
      dhcp4: no
      addresses:
        - $CLUSTER_IP/$(echo $CLUSTER_CIDR | cut -d'/' -f2)
EOF
        
        if [[ -n "$GATEWAY" ]]; then
            cat >> "$netplan_file" <<EOF
      routes:
        - to: default
          via: $GATEWAY
EOF
        fi
        
        cat >> "$netplan_file" <<EOF
      nameservers:
        addresses: [$(echo $DNS_SERVERS | sed 's/ /, /g')]
EOF
    fi
    
    # Apply netplan
    netplan apply
    
    # Verify IP assignment
    sleep 2
    if ip addr show "$CLUSTER_INTERFACE" | grep -q "$CLUSTER_IP"; then
        log_info "IP $CLUSTER_IP successfully assigned to $CLUSTER_INTERFACE"
    else
        log_error "Failed to assign IP to $CLUSTER_INTERFACE"
        exit 1
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
    
    # Check if ports are in use
    local ports_in_use=false
    for port in 6443 10250 10257 10259 2379 2380; do
        if ss -ltn | grep -q ":$port "; then
            log_warn "Port $port is in use"
            ports_in_use=true
        fi
    done
    
    if [[ "$ports_in_use" == true ]]; then
        log_warn "Some ports are in use. Running kubeadm reset..."
        kubeadm reset -f
        rm -rf /var/lib/kubelet /etc/kubernetes /var/lib/etcd /etc/cni /var/lib/cni
        systemctl stop kubelet
        sleep 2
        systemctl start kubelet
    fi
}

initialize_control_plane() {
    local init_cmd="kubeadm init --pod-network-cidr=$POD_CIDR"
    
    # Add API server advertise address if different from cluster IP
    if [[ "$API_ADDRESS" != "$CLUSTER_IP" ]] || [[ -n "$WIFI_INTERFACE" ]]; then
        init_cmd="$init_cmd --apiserver-advertise-address=$API_ADDRESS"
        log_info "API server will advertise on: $API_ADDRESS"
    fi
    
    log_info "Running: $init_cmd"
    $init_cmd
    
    if [[ $? -ne 0 ]]; then
        log_error "kubeadm init failed"
        exit 1
    fi
}

configure_kubectl() {
    # Configure for root user
    mkdir -p /root/.kube
    cp -f /etc/kubernetes/admin.conf /root/.kube/config
    chown root:root /root/.kube/config
    
    # Configure for the user who invoked sudo (if applicable)
    if [[ -n "${SUDO_USER:-}" ]] && [[ "$SUDO_USER" != "root" ]]; then
        local user_home=$(eval echo ~$SUDO_USER)
        mkdir -p "$user_home/.kube"
        cp -f /etc/kubernetes/admin.conf "$user_home/.kube/config"
        chown -R $SUDO_USER:$SUDO_USER "$user_home/.kube"
        log_info "kubectl configured for user $SUDO_USER"
    fi
}

install_flannel() {
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
    
    # Restart services to pick up CNI config
    log_info "Restarting containerd and kubelet to pick up CNI configuration"
    systemctl restart containerd
    systemctl restart kubelet
    
    sleep 5
}

wait_for_node_ready() {
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if kubectl get nodes | grep -q "Ready"; then
            log_info "Control plane node is Ready"
            kubectl get nodes
            return 0
        fi
        
        attempt=$((attempt + 1))
        log_info "Waiting for node to be ready... (attempt $attempt/$max_attempts)"
        sleep 10
    done
    
    log_error "Node did not become ready within expected time"
    kubectl get nodes
    kubectl get pods -A
    return 1
}

generate_join_command() {
    local join_cmd=$(kubeadm token create --print-join-command)
    
    # Save to file
    echo "#!/bin/bash" > /root/kubeadm-join-command.sh
    echo "# Generated on $(date)" >> /root/kubeadm-join-command.sh
    echo "$join_cmd" >> /root/kubeadm-join-command.sh
    chmod +x /root/kubeadm-join-command.sh
    
    log_info "Join command saved to /root/kubeadm-join-command.sh"
    echo ""
    echo "=========================================="
    echo "Worker nodes can join using this command:"
    echo "=========================================="
    cat /root/kubeadm-join-command.sh
    echo "=========================================="
    echo ""
}

# Run main function
main