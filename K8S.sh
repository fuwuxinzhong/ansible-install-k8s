nmcli con mod ens33 ipv4.method manual ipv4.address "192.168.188.128/24" ipv4.gateway 192.168.188.2
nmcli con mod ens33 ipv4.method manual ipv4.address "192.168.188.129/24" ipv4.gateway 192.168.188.2
nmcli con mod ens33 ipv4.method manual ipv4.address "192.168.188.130/24" ipv4.gateway 192.168.188.2

nmcli con mod ens33 ipv4.DNS "114.114.114.114 8.8.8.8"


systemctl stop firewalld
systemctl disable firewalld

setenforce 0
sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config

swapoff -a
sed -ri 's/.*swap.*/#&/' /etc/fstab 

hostnamectl set-hostname 
cat >> /etc/hosts << EOF
192.168.188.128 master1
192.168.188.129 node1
192.168.188.130 node2
EOF

# 将桥接的IPv4流量传递到iptables的链
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
# 生效
sysctl --system 


yum install ntpdate -y
ntpdate time.windows.com

#Centos8上
yum install chrony
chronyd -q 'server time.windows.com iburst'

wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
yum -y install docker-ce
systemctl enable docker && systemctl start docker

配置镜像下载加速器：
cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": [
  "native.cgroupdriver=systemd"
  ],
  "registry-mirrors": ["https://b9pmyelo.mirror.aliyuncs.com"]
}
EOF
systemctl daemon-reload
systemctl restart docker
docker info


cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF


yum install -y kubelet-1.20.0 kubeadm-1.20.0 kubectl-1.20.0


yum install -y kubelet kubeadm kubectl
systemctl enable kubelet
systemctl restart kubelet 


sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g"  /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
systemctl daemon-reload && systemctl restart kubelet

kubeadm init \
  --apiserver-advertise-address=192.168.188.128 \
  --kubernetes-version  v1.22.3\
  --image-repository registry.aliyuncs.com/google_containers \
  --service-cidr=10.96.0.0/12 \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=all


kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml


cat >> /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el8-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF





Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.188.128:6443 --token o0uma2.oukzm082bkn6y6iy \
        --discovery-token-ca-cert-hash sha256:8a22a4cb4105ed74c19108ab9ea36a23e2fcfd2a52f0e538da7a35ab02a89a0c


wget https://docs.projectcalico.org/manifests/calico.yaml --no-check-certificate
修改里面定义Pod网络（CALICO_IPV4POOL_CIDR），与前面kubeadm init的 --pod-network-cidr指定的一样


kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml


修改
spec:
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 30001
  selector:
    k8s-app: kubernetes-dashboard
  type: NodePort


kubectl create serviceaccount dashboard-admin -n kube-system
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin
kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')

eyJhbGciOiJSUzI1NiIsImtpZCI6Ilk4a0xNa3R0NGpselNaeHN0MGpiRzNJaGtOUkdiY2ZhdEhFRmhPcUh5SXMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkYXNoYm9hcmQtYWRtaW4tdG9rZW4tOGRsczIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGFzaGJvYXJkLWFkbWluIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiNjIyMzY4NTYtZjAwZC00NGM3LTliYTEtZjhiZTJjZGZjNDAxIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmRhc2hib2FyZC1hZG1pbiJ9.h78x8LloHqBvgSiUdT551j5utB15JvVvzf1l8y6WyttchLFUg9egVSDUJk-VIlZmiFFrOjyf2v99JxOIXIMrGsiG2E9oXM6Jdgzij1mCNlHx0Nj-qtHTZPSCzqaqIzi50Ed3lx4lryGAffeVFqtT_ESvTtYdkMDKb9Uvy_INbSUXE4gFb2Sj8Jn-cAM0HYwKFZ9E8tN7ymVfI53svajaJJ3KPz9gjfTAkjCHZaShnagz4pD6EuKyaB8CB3NElJ62gv9TDUTGajDRlNsNgLaQ17jFOutF0MoeVxyRSlSDw9rx1ShNF19GAmTB8_i2Q6tkQMYAXC3U9oo7MIDXvZHE0g



使用Deployment控制器部署镜像：
kubectl create deployment web --image=nginx --replicas=3
kubectl get deploy,pods
使用Service将Pod暴露出去：
kubectl expose deployment web --port=80 --target-port=80 --type=NodePort
kubectl get service
浏览器访问应用：
http://NodeIP:Port # 端口随机生成，通过get svc获取





查看升级过程
kubectl describe deployment web

记录发布命令
--record=ture 

install

