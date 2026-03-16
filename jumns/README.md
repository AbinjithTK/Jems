<p align="center">
  <img src="jems_icon.png" alt="Jems" width="80" />
</p>

<h1 align="center">Jems — Your Spatial AI Operating System</h1>

<p align="center">
  A multi-agent personal assistant powered by Google Gemini, built as a spatial OS with glassmorphism UI, autonomous planning, semantic memory, and social connectivity.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" />
  <img src="https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi" />
  <img src="https://img.shields.io/badge/Google_ADK-Multi--Agent-4285F4?logo=google" />
  <img src="https://img.shields.io/badge/Gemini-2.5_Flash_%2B_Pro-8E75B2" />
  <img src="https://img.shields.io/badge/GCP-Cloud_Run-4285F4?logo=googlecloud" />
  <img src="https://img.shields.io/badge/Firestore-NoSQL-FFCA28?logo=firebase" />
</p>

---

## Overview

Jems is a personal AI companion app with four specialized agents — Noor, Kai, Sage, and Echo — each owning a distinct screen and domain. The agents coordinate through a shared context bus, use semantic vector memory for long-term recall, and connect to external tools via MCP (Model Context Protocol) and friend agents via A2A (Agent-to-Agent) protocol.

---

## System Architecture

```mermaid
graph TB
    subgraph Client["📱 Flutter App"]
        UI["Spatial UI<br/>Glassmorphism + Agent Spheres"]
        WS["WebSocket Client"]
        REST["REST Client"]
    end

    subgraph GCP["☁️ Google Cloud Platform"]
        subgraph CloudRun["Cloud Run Service"]
            API["FastAPI Backend<br/>REST + WebSocket"]
            ADK["Google ADK<br/>Multi-Agent Runtime"]
        end

        subgraph AI["🧠 Vertex AI"]
            Flash["Gemini 2.5 Flash<br/>(Noor — voice + chat)"]
            Pro["Gemini 2.5 Pro<br/>(Kai, Sage, Echo — tools)"]
            Embed["text-embedding-004<br/>(Memory vectors)"]
        end

        subgraph Storage["💾 Data Layer"]
            Firestore["Firestore<br/>Users, Tasks, Goals,<br/>Reminders, Journal,<br/>Messages, Connections"]
            GCS["Cloud Storage<br/>Memory vectors,<br/>Proof uploads"]
        end

        subgraph Infra["⚙️ Infrastructure"]
            AR["Artifact Registry<br/>Docker images"]
            SM["Secret Manager<br/>Scheduler secret"]
            CS["Cloud Scheduler<br/>7 cron jobs"]
        end
    end

    subgraph External["🌐 External"]
        Firebase["Firebase Auth<br/>JWT tokens"]
        MCP_EXT["MCP Servers<br/>Dynamic tool integrations"]
        A2A_EXT["Friend Agents<br/>A2A protocol"]
        RevenueCat["RevenueCat<br/>Subscriptions"]
        Google["Google Search<br/>Web grounding"]
    end

    UI -->|"HTTPS"| REST
    UI -->|"WSS"| WS
    REST --> API
    WS --> API
    API --> ADK
    ADK --> Flash
    ADK --> Pro
    ADK --> Embed
    ADK --> Firestore
    ADK --> GCS
    CS -->|"POST /api/scheduler/*"| API
    API --> Firebase
    ADK --> MCP_EXT
    ADK --> A2A_EXT
    API --> RevenueCat
    ADK --> Google

    style Client fill:#EFF6FF,stroke:#3B82F6,stroke-width:2px
    style GCP fill:#F0FDF4,stroke:#22C55E,stroke-width:2px
    style External fill:#FFF7ED,stroke:#F97316,stroke-width:2px
    style CloudRun fill:#DCFCE7,stroke:#16A34A
    style AI fill:#EDE9FE,stroke:#8B5CF6
    style Storage fill:#FEF9C3,stroke:#CA8A04
    style Infra fill:#F1F5F9,stroke:#64748B
```

---

## Multi-Agent Hierarchy

```mermaid
graph TD
    User(("👤 User"))

    subgraph AgentSystem["ADK Multi-Agent System"]
        Noor["🟢 Noor<br/>Root Agent<br/>gemini-2.5-flash<br/><i>Hub · Chat · Voice</i>"]

        Kai["🟡 Kai<br/>Sub-Agent<br/>gemini-2.5-pro<br/><i>Tasks · Reminders · Plans</i>"]

        Sage["🩷 Sage<br/>Sub-Agent<br/>gemini-2.5-pro<br/><i>Goals · Growth · Social</i>"]

        Echo["🟣 Echo<br/>Sub-Agent<br/>gemini-2.5-pro<br/><i>Memory · Journal · Reflection</i>"]
    end

    ContextBus[("🔄 Context Bus<br/>Firestore agent_context<br/>24h TTL")]

    MCP["🔌 MCP Toolsets<br/>Per-user dynamic integrations"]
    Friends["👥 Friend Agents<br/>RemoteA2aAgent via A2A"]
    GoogleSearch["🔍 Google Search<br/>Web grounding"]

    User -->|"chat / voice"| Noor
    Noor -->|"transfer_to_agent"| Kai
    Noor -->|"transfer_to_agent"| Sage
    Noor -->|"transfer_to_agent"| Echo
    Noor --> MCP
    Noor --> Friends
    Noor --> GoogleSearch

    Kai -->|"publish"| ContextBus
    Sage -->|"publish"| ContextBus
    Echo -->|"publish"| ContextBus
    ContextBus -->|"read"| Kai
    ContextBus -->|"read"| Sage
    ContextBus -->|"read"| Echo
    ContextBus -->|"read"| Noor

    style Noor fill:#D1FAE5,stroke:#10B981,stroke-width:3px
    style Kai fill:#FEF08A,stroke:#FACC15,stroke-width:2px
    style Sage fill:#FCE7F3,stroke:#F472B6,stroke-width:2px
    style Echo fill:#EDE9FE,stroke:#8B5CF6,stroke-width:2px
    style ContextBus fill:#FFF7ED,stroke:#F97316,stroke-width:2px
```

---

## Data Flow — Chat Message Lifecycle

```mermaid
sequenceDiagram
    participant U as 👤 User (Flutter)
    participant WS as WebSocket
    participant API as FastAPI
    participant ADK as ADK Runtime
    participant Noor as 🟢 Noor
    participant Sub as 🟡/🩷/🟣 Sub-Agent
    participant Gemini as Gemini API
    participant Tools as Agent Tools
    participant FS as Firestore
    participant GCS as Cloud Storage

    U->>WS: {"type":"text", "text":"Plan my week"}
    WS->>API: Route to agent session
    API->>ADK: Create/resume session
    ADK->>Noor: Process user message
    Noor->>Gemini: Generate response (Flash)

    alt Domain-specific request
        Noor->>Sub: transfer_to_agent (Kai)
        Sub->>Gemini: Generate with tools (Pro)
        Sub->>Tools: create_task(), create_reminder()
        Tools->>FS: Write tasks/reminders
        Sub->>Tools: publish_context()
        Tools->>FS: Write to agent_context
        Sub-->>ADK: Tool results + response
    else General conversation
        Noor->>Tools: remember_fact(), web_search()
        Tools->>GCS: Store memory vector
        Noor-->>ADK: Response text
    end

    ADK-->>API: Stream events
    API-->>WS: {"type":"event", "text":"...", "author":"kai"}
    WS-->>U: Render in spatial UI
    API-->>WS: {"type":"turn_complete"}
