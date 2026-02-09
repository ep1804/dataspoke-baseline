# Data Spoke: The Active Governance Engine for DataHub

Data Spoke는 DataHub를 '정적인 메타데이터 저장소(GMS)'에서 '동적인 액션 엔진'으로 진화시키기 위한 Governance Sidecar 프로젝트입니다. DataHub를 Headless Backend로 활용하며, 표준 기능만으로 해결하기 어려운 복잡한 비즈니스 로직과 지능형 자동화를 구현하는 독자적인 확장 레이어를 지향합니다.

우리는 데이터 엔지니어가 겪는 운영상의 페인 포인트(Manual Sync, Quality Blindspot)를 해결함과 동시에, AI Agent가 데이터 인프라를 안전하고 정확하게 다룰 수 있도록 '데이터 맥락(Context)의 실시간 검증 레이어'를 제공합니다.

---

## 1. Problem Statement: The Gap in Metadata Utility

현대적인 데이터 거버넌스에서 범용 오픈소스(e.g. DataHub)는 다음과 같은 한계를 가집니다.

### For Conventional Pipelining

- Rigid Ingestion: 표준 ingestor의 경직성으로 인해 다양한 데이터 인프라에서 충분한 데이터를 동기화 하지 못하는 점.
- Static Metadata: 데이터의 흐름은 기록하지만, 데이터가 "살아있는지(Anomaly)"에 대한 지능적 판단 부족.
- UI Inflexibility: 조직마다 다른 품질 관리 워크플로우를 범용적인 UI에 맞추어야 하는 불편함.

### For AI Agents

- Discovery Gap: 단순 키워드 검색을 넘어, 데이터 간의 문맥(Context)을 이해하는 자연어 기반 탐색의 부재.
- Lack of Verification Loop: Agent가 생성한 파이프라인이 기존 데이터 계보(Lineage)에 어떤 영향을 줄지, 품질 기준을 통과할 수 있을지에 대한 실시간 피드백 루프가 부재합니다.
- Unstructured Knowledge Access: DataHub의 방대한 정보가 AI가 즉시 소화하기 어려운 구조로 산재해 있어, RAG(Retrieval-Augmented Generation) 생산성이 저하됩니다.

**Data Spoke는 이 두 절벽 사이를 잇는 지능형 바퀴살(Spoke)입니다.**

---

## 2. Core Capabilities: Hybrid Intelligence

### Robust Infrastructure Sync

- **Ingestion Management**: 중앙 집중식 Ingestion 설정 관리 및 실행 이력 추적
- **Custom Sync**: DataHub 표준 ingestion 커넥터외에 커스텀 로직을 통해 REST API 기반으로 데이터 인프라와 DataHub를 유연하게 동기화. In-house source code repository, SQL Engine Log 등 다양한 시스템에서의 데이터 동기화 설정. Slack conversation 등 unstructured data에서 정보를 추출 LLM으로 가공하여 동기화.
- **Headless Orchestration**: DataHub를 백엔드로 사용하며, 독자적인 저장소와 API를 통해 입맛에 맞는 거버넌스 워크플로우를 구축

### Advanced Observability & Quality

- **Custom Python Quality Model**: Rule 기반 검사를 넘어, Prophet/Isolation Forest 등 Python 기반 모델을 활용한 시계열 이상 탐지를 수행
- **Customized Quality UI**: DataHub의 표준 메트릭과 커스텀 검사 결과를 통합하여 한눈에 보여주는 전용 대시보드를 운영

### Metadata Health & Reporting

- **Documentation Auditor**: 설명 누락, 오기입된 메타데이터를 정기적으로 스캔하여 리포팅하고 관리 담당자(Owner)에게 액션을 촉구

### Agentic Knowledge Base (RAG-Ready)

- **Vectorized Metadata**: DataHub의 모든 정보를 임베딩하여 VectorDB에 실시간 동기화
- **Semantic Search API**: 인간과 AI Agent 모두에게 자연어 기반의 고차원 데이터 검색 인터페이스를 제공

---

## 3. Key Use Cases

### Case A: AI Pipeline Development Agent

AI가 "결제 테이블을 기반으로 정산 파이프라인을 짜줘"라는 요청을 받으면, Data Spoke를 도구로 사용합니다.

- **Context Grounding**: "해당 테이블은 현재 품질 이슈가 있으니 대체 테이블 B를 사용하라"는 가이드를 Data Spoke가 제공합니다.
- **Autonomous Verification**: Agent가 짠 코드가 사내 가이드라인(문서화, 명명 규칙)을 지켰는지 배포 전 실시간 검증합니다.

### Case B: Predictive Data SLA Management

단순히 데이터가 들어왔는지가 아니라, "평소 월요일 오전 대비 유입량이 20% 감소했다"는 시계열 분석 결과를 기반으로 파이프라인 상의 이상을 예견하고 대응합니다.

### Case C: Natural Language Data Discovery

"지난 분기 광고 로그 중 개인정보가 마스킹 처리되었고 신뢰도가 높은 테이블이 뭐야?"라는 질문에 대해, 단순 키워드가 아닌 문맥적 의미에 기반한 답변을 제공합니다.

### Case D: Metadata Health Management

전사적 데이터 자산 최적화: 문서화 점수(Documentation Score)를 기반으로 부서별 관리 상태를 지표화하고 개선을 유도합니다.

---

## 4. Architectural Concept: "Hub-and-Spoke"

Data Spoke는 DataHub와 **느슨한 결합(Loosely Coupled)**을 유지하며, 데이터의 실제적 가치를 창출하는 '바퀴살(Spoke)' 역할을 수행합니다.

- The Hub (DataHub GMS): 메타데이터의 영속성 및 표준 규격(Aspects) 관리를 담당하는 싱글 소스 오브 트루스(SSOT).
- The Spoke (Data Spoke): 비즈니스 로직, 고성능 캐싱(VectorDB), 시계열 분석, 커스텀 UI를 담당하는 연산 및 인터페이스 레이어.
- Communication: GraphQL 및 REST API를 통한 양방향 통신과 Kafka 기반의 실시간 이벤트 구독(MCE/MAE).

---

## Our Manifesto

> "우리는 메타데이터를 저장하는 것(Storage)에 그치지 않고, 그것을 움직이게(Action) 만든다. Data Spoke는 엔지니어에게는 정교한 통제권을, AI Agent에게는 완벽한 문맥을 제공함으로써, 자동화된 시대에도 변함없는 데이터 신뢰도를 보장한다."
