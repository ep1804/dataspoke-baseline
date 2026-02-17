# DataSpoke Baseline

AI Data Catalog Starter: Productized Scaffold for Custom Solutions

![DataSpoke MANIFESTO](../assets/MANIFESTO_image.jpg)

---

## 1. 문제 정의

### AI 시대, 데이터 카탈로그의 새로운 요구 조건

LLM과 AI Agent가 실무 환경에 깊숙이 침투함에 따라, 데이터 카탈로그는 단순한 메타데이터 저장소를 넘어 다음의 두 가지 핵심 기능을 수행해야 한다.

* **Online Verifier (실시간 검증)**: AI 코딩 루프 내에서 파이프라인 개발 결과물을 실시간으로 검증하는 기능.
* **Self-Purification (자기 정화)**: AI를 활용해 데이터 온톨로지를 설계하고, 데이터 정합성을 스스로 점검 및 교정하는 기능.

### 단일 카탈로그(Monolithic Catalog)의 한계

DataHub, Dataplex, OpenMetadata 등의 플랫폼은 방대한 기능을 제공하나, 실제 현장 활용도는 낮다. 이는 '모두를 만족시키려다 그 누구에게도 최적화되지 못한' 인터페이스가 되었기 때문이다.

* **사용자 그룹별 관심사의 괴리**: 데이터 엔지니어는 파이프라인의 이상 징후를, 분석가는 신뢰할 수 있는 테이블을, 보안팀은 PII(개인정보) 현황을 추적하고자 한다. 각자의 목적이 상이함에도 단일 뷰(View)를 강요받는다.
* **기능적 공백**: 표준 커넥터가 지원하지 못하는 레거시·비정형 데이터 소스 관리나, 정적 검증에 머물러 있는 품질 점검 등 운영 현장의 구체적인 요구사항을 기존 플랫폼이 수용하기에는 한계가 명확하다.

### 목표

본 프로젝트는 다음 두 가지 목표를 지향한다.

1. **Baseline Product**: AI 시대의 데이터 카탈로그가 갖춰야 할 필수 기본 기능을 정의하고 구현한다.
2. **Scaffold for AI coding**: 충분한 컨벤션, 개발 스펙, Claude Code 유틸리티를 제공하여, 각 조직에 특화된 '전용 카탈로그'를 AI로 단시간에 구축할 수 있는 개발 스캐폴드를 제공한다.

프로젝트 명 **DataSpoke**는 기존 DataHub를 중심(Hub)으로 두고, 각 조직의 니즈에 맞춘 특화 확장판을 바퀴살(Spoke)로 정의하는 구조에서 비롯되었다.

### 저장소 구성 요소

* **Baseline Product**: Online Verifier, Self-Purification 등 공통 핵심 기능의 구현체.
* **Claude Code 유틸리티**: Command, Skill, Subagent, Agent Team 설정 등 AI 코딩 루프를 즉시 구동할 수 있는 환경.
* **Development Spec**: 개발 환경 셋업, Hub-Spoke 간 API 규격, 기능 상세 스펙 및 아키텍처 문서.

---

## 2. 주요 기능

### Ingestion (메타 수집)

* **Configuration and Orchestration of Ingestion**: 일부 메타에 대해서는 메타 수집 설정을 등록하여 관리할 수 있으며, 자체 Orchestration으로 업데이트 한다.
* **Python-based Custom Ingestion**: 레거시 및 비정형 데이터 소스에 대한 유연한 접근을 지원한다.

### Quality Control (품질 관리)

* **Python-based Quality Model**: 머신러닝 기반의 시계열 이상 탐지 등 고도화된 품질 모델을 지원한다.

### Self-Purifier (자기 정화)

* **Documentation Auditor**: 메타데이터의 오류를 자동 스캔하고 데이터 소유자(Owner)에게 알림을 발송한다.
* **Health Score Dashboard**: 팀별 데이터 문서화 점수 및 품질 현황을 추적한다.

### Knowledge Base & Verifier (지식 베이스 및 검증)

* **Semantic Search API**: RAG(Retrieval-Augmented Generation) 최적화를 고려한 자연어 기반 탐색 인터페이스를 제공한다.
* **Context Verification API**: AI 에이전트가 코딩 루프 중에 생성한 데이터의 품질을 실시간으로 검증한다.

---

## 3. Architecture

DataSpoke는 DataHub와 연동되면서도 독립적으로 배포되는 **사이드카(Sidecar) 애플리케이션**이다.

* **The Hub (DataHub GMS)**: 메타데이터의 '단일 진실 공급원(Single Source of Truth)'. 메타데이터 영속성 및 표준 스키마를 관리하며, GraphQL/REST API 및 Kafka를 통해 DataSpoke와 양방향으로 통신한다.
* **The Spoke (DataSpoke)**: Hub가 제공하지 않는 비즈니스 로직과 전용 UX 레이어를 담당한다. FastAPI와 Next.js를 기반으로 하며, 모든 기능 그룹에 걸쳐 공유되는 **Management & Orchestration** 레이어(워크플로우 엔진, 스케줄링, 운영 API)를 운영하며, 필요에 따라 자체 VectorDB, 분석 인프라를 병행 운용한다.
