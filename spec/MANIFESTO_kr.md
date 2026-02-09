# Data Spoke: The Active Governance Engine for DataHub

Data Spoke는 DataHub를 정적 메타데이터 저장소에서 동적 액션 엔진으로 전환하는 Governance Sidecar입니다. DataHub를 Headless Backend로 활용하여 복잡한 비즈니스 로직과 지능형 자동화를 구현합니다.

데이터 엔지니어의 운영 병목(Manual Sync, Quality Blindspot)을 해소하고, AI Agent를 위한 데이터 컨텍스트 검증 레이어를 제공합니다.

---

## 1. Problem Statement

범용 메타데이터 플랫폼의 한계:

### 기존 파이프라인 운영
- **Rigid Ingestion**: 표준 커넥터의 한계로 인한 불완전한 데이터 동기화
- **Static Metadata**: 데이터 흐름 기록 기능만 제공하며 이상 탐지 부재
- **UI Inflexibility**: 조직별 워크플로우를 수용하지 못하는 범용 인터페이스

### AI Agent 활용
- **Discovery Gap**: 키워드 검색 기반, 컨텍스트 인식 자연어 탐색 부재
- **Verification Loop**: 파이프라인 생성 시 영향도 및 품질 검증 피드백 부재
- **Unstructured Access**: RAG 최적화되지 않은 메타데이터 구조

**Data Spoke는 두 영역을 연결하는 지능형 확장 레이어입니다.**

---

## 2. Core Capabilities

### Infrastructure Sync
- **Ingestion Management**: 중앙 집중식 설정 관리 및 실행 이력 추적
- **Custom Sync**: REST API 기반 유연한 동기화 (Source Repository, SQL Engine Log, Slack 등 비정형 데이터 LLM 가공)
- **Headless Orchestration**: 독자적 저장소와 API를 통한 커스텀 워크플로우 구축

### Observability & Quality
- **Python Quality Model**: Prophet/Isolation Forest 등 ML 기반 시계열 이상 탐지
- **Unified Dashboard**: DataHub 표준 메트릭과 커스텀 검사 결과 통합 뷰

### Metadata Health
- **Documentation Auditor**: 메타데이터 누락 및 오류 자동 스캔 및 Owner 알림

### AI-Ready Knowledge Base
- **Vectorized Metadata**: VectorDB 실시간 동기화를 통한 임베딩 기반 검색
- **Semantic Search API**: 자연어 기반 메타데이터 검색 인터페이스

---

## 3. Key Use Cases

### AI Pipeline Development
AI Agent가 파이프라인 생성 시 Data Spoke를 통해 컨텍스트 검증 및 가이드라인 준수를 자동 확인
- Context Grounding: 품질 이슈 테이블 회피 및 대체 옵션 제시
- Autonomous Verification: 사내 표준 (문서화, 명명 규칙) 실시간 검증

### Predictive SLA Management
시계열 분석 기반 이상 패턴 조기 탐지 (예: 월요일 오전 대비 20% 유입량 감소)

### Semantic Data Discovery
자연어 질의 기반 컨텍스트 인식 검색 (예: "Q1 광고 로그 중 PII 마스킹된 고신뢰도 테이블")

### Metadata Health Monitoring
Documentation Score 기반 부서별 메타데이터 품질 지표화 및 개선 유도

---

## 4. Architecture: Hub-and-Spoke Model

Data Spoke는 DataHub와 느슨한 결합을 유지하며 실제적 가치를 창출하는 확장 레이어입니다.

- **The Hub (DataHub GMS)**: 메타데이터 영속성 및 표준 규격 관리 (Single Source of Truth)
- **The Spoke (Data Spoke)**: 비즈니스 로직, VectorDB 캐싱, 시계열 분석, 커스텀 UI 레이어
- **Communication**: GraphQL/REST API 양방향 통신 및 Kafka 기반 실시간 이벤트 구독 (MCE/MAE)

---

## Manifesto

> "메타데이터를 저장하는 것을 넘어, 움직이게 만든다. Data Spoke는 엔지니어에게 정교한 제어를, AI Agent에게 정확한 컨텍스트를 제공하여 자동화 시대의 데이터 신뢰도를 보장한다."
