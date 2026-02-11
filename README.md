# 🌍 Terraform Infrastructure as Code (IaC) — Mono Repo

This repository serves as a **central collection of multiple Terraform projects**, each designed to provision and manage different pieces of cloud infrastructure using **Infrastructure as Code (IaC)**.

Instead of maintaining separate repositories for each Terraform project, all related Terraform deployments are organized here for better consistency, reusability, and maintainability.

---

## 📌 Repository Overview

This repo contains multiple independent Terraform projects. Each project has its own folder, state, and configuration, and can be deployed separately.

### 🎯 Goals of this repository

* Organize all Terraform projects in one place
* Follow Infrastructure as Code best practices
* Make cloud resource provisioning repeatable and automated
* Enable easy learning, reference, and reuse
* Support multiple environments (dev, staging, prod — where applicable)

---

## 📂 Repository Structure (Example)

```bash
.
├── project-1-aws-vpc/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
│
├── project-2-ec2-setup/
│   ├── main.tf
│   ├── variables.tf
│   └── providers.tf
│
├── project-3-s3-cloudfront/
│   ├── main.tf
│   ├── modules/
│   └── backend.tf
│
├── project-4-eks-cluster/
│   ├── main.tf
│   ├── eks/
│   └── variables.tf
│
└── README.md   <-- (You are here)
```

> 📌 **Each folder is a separate Terraform project** and can be initialized and applied independently.

---

## 🏗️ What’s Included (Examples)

This repository includes Terraform projects for:

* ✅ AWS VPC with public & private subnets
* ✅ EC2 instance provisioning
* ✅ S3 + CloudFront static website hosting
* ✅ IAM roles and policies
* ✅ EKS Kubernetes cluster setup
* ✅ Networking (Route tables, NAT Gateway, IGW, Security Groups)
* ✅ CI/CD-friendly Terraform structure

*(You can modify this list based on your actual projects.)*

---

## 🛠️ How to Use Any Project

### 1️⃣ Navigate to a project folder

```bash
cd project-1-aws-vpc
```

### 2️⃣ Initialize Terraform

```bash
terraform init
```

### 3️⃣ Validate configuration

```bash
terraform validate
```

### 4️⃣ Preview changes

```bash
terraform plan
```

### 5️⃣ Apply infrastructure

```bash
terraform apply -auto-approve
```

---

## ⚠️ Destroy Resources (Be Careful!)

To delete resources in a specific project:

```bash
terraform destroy -auto-approve
```

> ⚠️ Run this **inside the correct project folder only**.

---

## 📦 State Management

Each project may use:

* Local state (`terraform.tfstate`) **or**
* Remote backend (S3 + DynamoDB for locking)

Check the respective project folder for backend configuration.

---

## 🤝 Contributing

If you want to add a new Terraform project:

1. Create a new folder: `project-name/`
2. Add Terraform files (`main.tf`, `variables.tf`, etc.)
3. Update this README with a short description of the new project
4. Submit a pull request 🚀

---

## 👨‍💻 Author

**Zia Saeed**
GitHub: [https://github.com/Zia-Saeed](https://github.com/Zia-Saeed)

---

⭐ If you find this useful, please consider starring this repository!
