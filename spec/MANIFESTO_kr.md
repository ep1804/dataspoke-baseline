# DataSpoke Spec: A Meal Kit Software for Customized Data Catalog

사용자 그룹마다 다르게 커스터마이즈된 데이터 카달로그가 필요할 수 있다. 데이터 엔지니어, 마케팅 DA, 프로덕트 DA, 머신러너, 신규 기능 스쿼드, 보안팀. 이런 다양한 사용자의 모든 요구를 하나의 중앙 데이터 카달로그가 전부 소화하는 것은 쉽지 않다. 또한, 모든 기능을 담는 순간 누구에게도 접근하기 어려운 시스템이 되어 버린다. 현존하는 데이터 카달로그 오픈소스들은 압도적인 스펙과 넘쳐나는 기능을 가지고 있지만, 바로 그 점이 사람들이 데이터 카달로그를 충분히 활용하지 못하는 첫번째 이유이다.

AI Agent가 쓸만해지면서, 데이터 카달로그의 기능은 두 가지 측면에서 더 늘어나고 있다. 첫번째는 AI Agent Coding Loop를 통한 데이터 파이프라인 개발 자동화를 지원하는, Online Verifier로서의 기능이다. 두번째는 AI Agent를 활용하여 데이터 온톨로지를 스스로 설계하고, 그에 따른 데이터의 정합성과 일관성을 스스로 점검하는, 일종의 자정(Self-purification) 기능이다. 이 두가지 방향의 확장은 데이터 카달로그를 지급보다도 더 복잡한 것으로 만들 가능성이 있고, 이에 따른 커스터마이즈에 대한 요구는 더 커질수도 있다.

이 프로젝트에서 시도해보고자 하는 것은 앞서 첫번째 문장에서 언급한 ‘사용자 그룹마다 커스터마이즈된 데이터 카달로그’를 개발하는 쉬운 방법을 제공하는 것이다. 어려운 요리를 빠른 시간에 만들어주는 반조리 식품(Meal Kit)과 같이 복잡한 소프트웨어를 빠르게 구축해주는 반조리 소프트웨어(Meal Kit Software)를 만들고자 한다. 구체적으로, 중앙 데이터 카달로그로 DataHub를 사용한다고 가정하고, Claude Code를 활용해 커스터마이즈된 데이터 카달로그를 단 몇 시간만에 구축할 수 있도록 해주는 설정과 스펙을 만들고자 하며, 이 커스터마이즈에는 AI 기반의 업무에서 큰 역할을 담당하기 위한 기능까지 포함한다.

이 프로젝트에서 DataHub의 사용자 그룹별 커스터마이즈 형태를 DataSpoke라고 부르겠다. DataSpoke Spec은 DataSpoke를 단시간에 구축하는 AI Coding Loop를 구동하기 위한 다양한 설정과 스펙 문서를 의미하며, 다음과 같은 내용을 포함한다: 

- Claude Code 유틸리티 셋팅: Command, Skill, Subagent, Agent Team 등
- 개발 스펙: 개발 환경 셋업, Hub-Spoke간 API, 기능 스펙 템플릿, 아키텍쳐 등
- 샘플 커스터마이즈 프로덕트: 개발 스펙에 커스텀 기능을 추가해서 실제 프로덕트를 구현한 샘플 캐이스

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
