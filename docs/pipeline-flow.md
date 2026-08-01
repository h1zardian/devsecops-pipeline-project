# Pipeline Flow & Security Gates

```mermaid
graph LR
    A["Push to main<br/>(app/ changed)"] --> B["Secrets Scan<br/>gitleaks"]
    B --> C["SAST Scan<br/>bandit"]
    C --> D["Build Image<br/>buildah build"]
    D --> E["Pre-Push Gate<br/>Trivy Scan (CRITICAL/HIGH)"]
    E --> F["Push to GHCR<br/>buildah push"]
    F --> G["SBOM Attestation<br/>syft → CycloneDX"]
    G --> H["Keyless Signature<br/>cosign sign"]
    H --> I["SLSA L3 Provenance<br/>slsa-github-generator"]
    I --> J["GitOps Update<br/>commit new tag to values.yaml"]

    style A fill:#1a1a2e,stroke:#e94560,color:#fff
    style B fill:#16213e,stroke:#e94560,color:#fff
    style C fill:#16213e,stroke:#e94560,color:#fff
    style D fill:#0f3460,stroke:#53d8fb,color:#fff
    style E fill:#8b0000,stroke:#e94560,color:#fff
    style F fill:#0f3460,stroke:#53d8fb,color:#fff
    style G fill:#0f3460,stroke:#53d8fb,color:#fff
    style H fill:#533483,stroke:#e94560,color:#fff
    style I fill:#533483,stroke:#e94560,color:#fff
    style J fill:#1a5c2e,stroke:#53d8fb,color:#fff
```
