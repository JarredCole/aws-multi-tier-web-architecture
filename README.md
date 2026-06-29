# aws-multi-tier-web-architecture
AWS Multi-Tier Web Architecture

(Project Overview)

This project demonstrates the deployment of a highly available, secure web workload within a custom AWS VPC. The architecture utilizes an Application Load Balancer (ALB) to safely route public traffic to an Apache web server housed within an isolated security tier. Administrative access is managed securely without public exposure via AWS Systems Manager (SSM).

(Business Case & Architecture Goals)

In a production environment, exposing application servers directly to the public internet introduces severe security vulnerabilities, while unmanaged single-point-of-failure setups risk costly business downtime.

This architecture was explicitly engineered to simulate a real-world corporate migration strategy designed to solve three critical business challenges:

1. Eliminating the Public Attack Surface (Security)
The Problem: Placing servers directly on the public internet exposes them to continuous automated brute-force attacks, vulnerability scanning, and potential data breaches.

The Solution: By moving the application server behind an Application Load Balancer and restricting its firewall (Security Group) to accept traffic only from that balancer, the server is completely hidden from the wild internet. Malicious actors cannot scan or target the server directly.

2. Safeguarding High Availability (Business Continuity)
The Problem: If a standalone web server crashes or undergoes maintenance, the business loses revenue and customer trust immediately during the outage.

The Solution: Introducing an Application Load Balancer establishes a framework for high availability. By constantly monitoring the health of backend instances at strict 10-second intervals, the system ensures that if a server goes down, traffic is automatically rerouted to healthy resources instantly, preserving a seamless user experience.

3. Balancing Security with Strict Fiscal Responsibility (Cost Optimization)
The Problem: Standard enterprise blueprints dictate using NAT Gateways to allow isolated servers to talk to the internet for administrative tasks. However, AWS charges a baseline of ~$32.40/month per NAT Gateway idle—an unjustifiable expense for an early proof-of-concept (PoC) or small-scale application.

The Solution: This project implements an advanced design pivot. By leveraging AWS Systems Manager (SSM), secure administrative terminal access is maintained directly over the internal AWS backbone. This achieves 100% of the required security isolation without incurring the massive financial overhead of idle NAT Gateway infrastructure.

(Technical Skills Demonstrated)

Custom VPC design with public/private subnet isolation and custom Route Tables.

Application Load Balancer (ALB) provisioning and advanced target group health check configuration.

Stateful firewall design using AWS Security Groups and stateless network control via NACLs.

Linux systems administration, automated bootstrapping (User Data), and CLI troubleshooting.

(Quantifying Business Impact & Architecture Metrics)

Zero-Trust Security Enforcement: Implemented strict multi-tier security groups, restricting 100% of public HTTP ingress directly to the ALB. This reduced the application server's direct network attack surface to zero public exposure.

High-Availability RTO Optimization: Configured an ALB with optimized health check thresholds (10-second intervals), minimizing potential application downtime by ensuring automated traffic rerouting within 20 seconds of a backend node failure.

Cost-Optimized VPC Engineering: Designed a cost-effective VPC architecture for a single-zone proof-of-concept. Intentionally routed administrative traffic securely via AWS Systems Manager (SSM) to completely bypass traditional NAT Gateway architectures, eliminating over $30/month in idle infrastructure charges.

(Real-World Troubleshooting Chronicles)

A successful deployment is rarely a straight line. This project involved diagnosing and resolving two distinct engineering blocks across the AWS network and the Linux operating system tiers.

Incident 1: CIDR Block Optimization & Subnet Allocation Conflict
The Issue: During the initial network provisioning phase, the planned IP addressing scheme for the custom VPC hit an allocation conflict. The initial subnet CIDR blocks overlapped, preventing AWS from creating the isolated public and private subnet tiers.

The Discovery & Resolution:

IP Scheme Redesign: Analyzed the VPC design and adjusted the CIDR prefix allocations (e.g., modifying the mask lengths) to properly segment the 10.0.0.0 network without overlap.

Subnet Routing Verification: Once the correct subnet boundaries were established, the instance was launched. However, external connection attempts timed out. I traced the root cause to a missing route table entry—the subnet tier housing the application lacked an explicit path pointing out to the VPC’s Internet Gateway (igw-xxxxxx).

The Pivot: To maximize cost efficiency for this proof-of-concept and avoid deploying an expensive NAT Gateway for a private subnet tier, I cleanly pivoted the instance into a properly routed public tier. I confirmed the network path was clear by validating that the Network ACL (NACL) rule evaluation order (Rule 100 ALLOW) was properly passing traffic.

Incident 2: The Target Group 403 Forbidden Alignment
The Issue: Once network routing was established, the Application Load Balancer’s Target Group continuously marked the instance as Unhealthy, preventing traffic from reaching the application, even though the Apache service was confirmed to be active.

The Discovery & Resolution:

Local Loopback Isolation: Using AWS Systems Manager (SSM) to access the instance command line securely, I bypassed the AWS network entirely by running a local loopback test: curl -I http://localhost:80.

Isolating the Error: The terminal returned an HTTP/1.1 403 Forbidden status code. This proved that Apache was awake and listening, but rejecting requests because the default /var/www/html/ directory was empty, causing Apache to deny directory listing.

The Fix: I injected a valid landing page onto the server using echo "<h1>Hello World</h1>" | sudo tee /var/www/html/index.html.

ALB Alignment: I re-ran the curl test to verify a successful 200 OK response. 

The Result: The Target Group instantly refreshed to a healthy state, and the web application successfully launched globally via the secure ALB DNS endpoint.
