# DataSpoke: 상세 유스케이스 시나리오

> **문서 목적 안내**
> 이 문서는 아이디어 정립과 비전 정렬을 위한 개념적 시나리오를 제시합니다. 각 유스케이스는 DataSpoke의 의도된 기능과 가치를 보여주지만, 구현 사양이나 기술 요구사항은 아닙니다. 실제 구현 세부사항, 기술 아키텍처, 기능 우선순위는 별도의 기술 사양 문서에서 정의합니다.

이 문서는 DataSpoke가 세 가지 사용자 그룹 — **데이터 엔지니어링(DE)**, **데이터 분석(DA)**, **데이터 거버넌스(DG)** — 에 걸쳐 DataHub 기능을 어떻게 강화하는지 실제적 시나리오로 설명합니다.

모든 시나리오는 가상의 온라인 서점 **Imazon**이라는 단일 회사 컨텍스트를 공유하며, 유스케이스들이 공존하고 상호 보완됩니다.

---

## 가상 회사 프로필: Imazon

Imazon은 설립 15년차 온라인 서점입니다. 데이터 환경은 오랜 유기적 성장을 반영합니다:

- **레거시 Oracle 데이터 웨어하우스** — 도서 카탈로그, 고객, 주문, 리뷰, 출판사, 재고, 배송을 다루는 500개 이상의 테이블
- **부서** — 엔지니어링, 데이터 사이언스, 마케팅, 재무, 법무, 운영, 출판사 관계, 고객 지원
- **주요 데이터 도메인** — `catalog.*` (도서, 저자, 장르), `customers.*`, `orders.*`, `reviews.*`, `recommendations.*`, `publishers.*`, `inventory.*`, `shipping.*`
- **DataHub 도입** — 최근 배포 완료. 표준 Oracle 커넥터가 스키마 메타데이터를 가져왔지만, 비즈니스 컨텍스트, 스토어드 프로시저 리니지, Confluence와 스프레드시트에 잠긴 조직 내 암묵지는 누락됨

---

## 기능 매핑

| 유스케이스 | 사용자 그룹 | 기능 |
|-----------|-----------|------|
| [유스케이스 1: Deep Ingestion — 레거시 도서 카탈로그 보강](#유스케이스-1-deep-ingestion--레거시-도서-카탈로그-보강) | DE | 심층 기술 사양 인제스천 |
| [유스케이스 2: Online Validator — 추천 파이프라인 검증](#유스케이스-2-online-validator--추천-파이프라인-검증) | DE / DA | 온라인 데이터 검증기 |
| [유스케이스 3: Predictive SLA — 배송 파이프라인 조기 경보](#유스케이스-3-predictive-sla--배송-파이프라인-조기-경보) | DE | 온라인 데이터 검증기 |
| [유스케이스 4: Doc Suggestions — 인수 후 온톨로지 통합](#유스케이스-4-doc-suggestions--인수-후-온톨로지-통합) | DE | 자동 문서화 제안 |
| [유스케이스 5: NL Search — GDPR 컴플라이언스 감사](#유스케이스-5-nl-search--gdpr-컴플라이언스-감사) | DA | 자연어 검색 |
| [유스케이스 6: Metrics Dashboard — 전사 메타데이터 건강도](#유스케이스-6-metrics-dashboard--전사-메타데이터-건강도) | DG | 전사 메트릭 시계열 모니터링 |

---

## 데이터 엔지니어링(DE) 그룹

### 유스케이스 1: Deep Ingestion — 레거시 도서 카탈로그 보강

**기능**: 심층 기술 사양 인제스천

#### 시나리오: 레거시 Oracle 도서 카탈로그 메타데이터 보강

**배경:**
Imazon의 Oracle 데이터 웨어하우스는 15년에 걸쳐 구축된 500개 이상의 테이블을 보유하고 있습니다. 표준 DataHub 커넥터는 스키마 메타데이터(테이블명, 컬럼 타입, 기본키)만 수집했으며, 데이터베이스 외부에 저장된 풍부한 비즈니스 컨텍스트를 놓쳤습니다: 편집 분류 체계를 기술하는 Confluence 페이지, ISBN-출판사 매핑 Excel 피드, 장르 분류 내부 API, 그리고 베스트셀러 순위와 로열티 계산을 수행하는 PL/SQL 스토어드 프로시저에 숨겨진 리니지 등이 그것입니다.

#### DataSpoke 없이

표준 Oracle 커넥터 결과: 컬럼 타입과 키만 있는 500개 테이블. 비즈니스 설명(Confluence에 저장), 출판사 메타데이터(Excel), 장르 분류 체계(API), 스토어드 프로시저 리니지 모두 없음. 데이터 소비자가 DataHub를 탐색해도 `catalog.title_master`가 실제로 무엇을 추적하는지, `reports.monthly_royalties`가 어떻게 계산되는지 알 수 없는 맨 기술 스키마만 보게 됩니다.

#### DataSpoke와 함께

**다중 소스 보강 설정 등록:**

```python
# POST /api/v1/spoke/de/ingestion/configs
dataspoke.ingestion.register_config({
  "name": "oracle_book_catalog_enriched",
  "source_type": "oracle",
  "schedule": "0 2 * * *",  # 매일 오전 2시

  "enrichment_sources": [
    {
      "type": "confluence",
      "space": "BOOK_DATA_DICTIONARY",
      "page_prefix": "Table: ",
      "fields_mapping": {
        "description": "confluence.content.body",
        "business_owner": "confluence.labels.owner",
        "pii_classification": "confluence.labels.pii"
      }
    },
    {
      "type": "excel",
      "path": "s3://imazon-docs/publisher-feeds/isbn-imprint-mapping.xlsx",
      "sheet": "ISBN_Classifications",
      "key_column": "table_name",
      "fields_mapping": {
        "publisher_domain": "Imprint",
        "content_rating": "Rating",
        "genre_taxonomy": "Genre_Path"
      }
    },
    {
      "type": "custom_api",
      "endpoint": "https://taxonomy-api.imazon.internal/genres",
      "auth": "bearer_token",
      "fields_mapping": {
        "genre_hierarchy": "$.genre.path",
        "editorial_tags": "$.genre.editorial_tags"
      }
    }
  ],

  "custom_extractors": [
    {
      "name": "plsql_lineage_parser",
      "type": "python_function",
      "module": "dataspoke.custom.oracle_lineage",
      "function": "extract_stored_proc_lineage",
      "params": { "parse_insert_select": true, "parse_merge_statements": true }
    },
    {
      "name": "quality_rule_extractor",
      "type": "python_function",
      "module": "dataspoke.custom.oracle_quality",
      "function": "extract_check_constraints_as_rules"
    }
  ]
})
```

**커스텀 PL/SQL 리니지 추출기** (발췌):

```python
# dataspoke/custom/oracle_lineage.py
class OraclePLSQLLineageExtractor(CustomExtractor):
    def extract_stored_proc_lineage(self, procedure_name, procedure_body, params):
        lineage_edges = []
        for stmt in sqlparse.parse(procedure_body):
            if self._is_insert_select(stmt):
                for source in self._extract_source_tables(stmt):
                    lineage_edges.append(LineageEdge(
                        source_urn=f"urn:li:dataset:(urn:li:dataPlatform:oracle,{source},PROD)",
                        target_urn=f"urn:li:dataset:(urn:li:dataPlatform:oracle,{self._extract_target_table(stmt)},PROD)",
                        transformation_type="stored_procedure",
                        transformation_logic=procedure_name,
                        confidence_score=0.95
                    ))
        return lineage_edges
```

**보강된 메타데이터 예시 — `catalog.title_master`:**

```yaml
Dataset: catalog.title_master
Platform: Oracle / DWPROD

# 기본 스키마 (표준 커넥터)
Columns: 62 | Primary Key: isbn, edition_id

# 보강 — 비즈니스 컨텍스트 (Confluence)
Description: |
  모든 도서 타이틀의 마스터 카탈로그. ISBN+에디션 당 1행.
  가격, 재고 현황, 편집 분류의 원천(Source of Truth).
  출판사 피드와 편집 검토 큐에서 매일 야간 업데이트.

# 보강 — 소유권 (Confluence + HR API)
Owner: maria.garcia@imazon.com | Team: 카탈로그 엔지니어링

# 보강 — 출판사 메타데이터 (Excel)
Publisher Domain: 전체 임프린트 | Genre Taxonomy: 4단계 계층

# 보강 — 리니지 (PL/SQL 파서)
Upstream: publishers.feed_raw, editorial.review_queue, pricing.base_rates
Generated By: PROC_NIGHTLY_CATALOG_REFRESH (스토어드 프로시저)
Downstream: recommendations.book_features, reports.catalog_summary

# 보강 — 품질 규칙 (CHECK 제약조건)
1. list_price > 0
2. publication_date <= SYSDATE
3. isbn IS NOT NULL AND LENGTH(isbn) IN (10, 13)
```

#### DataHub 연동 포인트

모든 보강된 메타데이터는 `DatahubRestEmitter` → `POST /openapi/entities/v1/`을 통해 DataHub에 저장됩니다. 각 카테고리는 MCP로 발행되는 DataHub aspect에 매핑됩니다:

| 인제스천 단계 | DataHub Aspect | 저장 내용 |
|-------------|---------------|----------|
| 기본 스키마 | `schemaMetadata` | 컬럼명, 타입, 키 |
| 비즈니스 설명 | `datasetProperties` | Confluence에서 가져온 `description` |
| PII / 편집 태그 | `globalTags` | `urn:li:tag:PII`, `urn:li:tag:Editorial_Reviewed` |
| 출판사 분류 | `datasetProperties.customProperties` | `publisher_domain`, `genre_taxonomy`, `content_rating` |
| 소유권 | `ownership` | Owner URN + `BUSINESS_OWNER` 타입 |
| PL/SQL 리니지 | `upstreamLineage` | 소스 → 타겟 데이터셋 URN 엣지 |
| 품질 규칙 | `assertionInfo` + `assertionRunEvent` | CHECK 제약조건을 assertion으로 변환 |

```python
emitter = DatahubRestEmitter(gms_server=DATAHUB_GMS_URL, token=DATAHUB_TOKEN)
dataset_urn = make_dataset_urn(platform="oracle", name="catalog.title_master", env="PROD")

# 설명 + 커스텀 속성
emitter.emit_mcp(MetadataChangeProposalWrapper(entityUrn=dataset_urn, aspect=DatasetProperties(
    description="모든 도서 타이틀의 마스터 카탈로그...",
    customProperties={"genre_taxonomy": "4-level", "publisher_domain": "All imprints"}
)))

# 스토어드 프로시저에서 추출한 리니지
emitter.emit_mcp(MetadataChangeProposalWrapper(entityUrn=dataset_urn, aspect=UpstreamLineage(
    upstreams=[Upstream(
        dataset=make_dataset_urn(platform="oracle", name="publishers.feed_raw", env="PROD"),
        type=DatasetLineageTypeClass.TRANSFORM
    )]
)))
```

> **핵심 포인트**: DataHub는 보강 로직을 제공하지 않습니다 — DataSpoke가 보낸 것만 저장합니다.

#### DataSpoke 커스텀 구현

| 컴포넌트 | 책임 | DataHub가 할 수 없는 이유 |
|---------|------|------------------------|
| **인제스천 설정 레지스트리** | 보강 설정(연결, 필드 매핑, 추출기) 저장 | DataHub 레시피는 표준 커넥터만 처리 |
| **보강 소스 커넥터** | Confluence, Excel/S3, 분류 체계 API에서 가져오기 | DataHub 커넥터는 데이터베이스/플랫폼 중심 |
| **커스텀 추출기 프레임워크** | PL/SQL 리니지 파싱, CHECK 제약조건 추출 플러그인 | 스토어드 프로시저 본문 파싱은 DataHub 범위 밖 |
| **필드 매핑 엔진** | Confluence 라벨 → 태그, Excel 컬럼 → 커스텀 속성 변환 | DataHub는 구조화된 aspect를 수용하지만 비정형 입력을 변환하지 않음 |
| **오케스트레이션 (Temporal)** | 스케줄링, 단계별 재시도, 알림 | DataHub는 레시피를 원자적으로 실행; 다중 소스 오케스트레이션은 Temporal 필요 |
| **벡터 인덱스 동기화** | 성공적 인제스천 시 임베딩 생성 → Qdrant | DataHub는 Elasticsearch 키워드 검색만 제공, 벡터 유사도 검색 없음 |

#### 결과

| 항목 | 표준 커넥터 | DataSpoke Deep Ingestion |
|-----|-----------|--------------------------|
| 스키마 커버리지 | 500 테이블 | 500 테이블 |
| 비즈니스 설명 | 0% | 89% (445/500) |
| 소유권 | 0% | 74% (370/500) |
| 장르 / 출판사 태그 | 0% | 100% |
| 스토어드 프로시저 리니지 | 미지원 | 210개 엣지 추출 |
| 품질 규칙 | 수동 입력만 가능 | 380개 자동 추출 |
| 갱신 주기 | 수동 재실행 | 자동 일일 실행 |

---

### 유스케이스 2: Online Validator — 추천 파이프라인 검증

**기능**: 온라인 데이터 검증기 (DA 그룹과 공유)

#### 시나리오: AI 에이전트가 도서 추천 파이프라인을 구축

**배경:**
데이터 사이언티스트가 AI 에이전트에게 요청합니다: "`reviews.user_ratings`와 `orders.purchase_history`를 사용해서 일일 도서 추천 파이프라인을 만들어줘." Validator는 에이전트가 건강한 데이터 소스를 선택하고 규정을 준수하는 결과물을 생성하도록 보장합니다.

#### DataSpoke 없이

AI 에이전트가 DataHub에서 "reviews"와 "orders" 테이블을 검색하고, 네이밍 규칙으로 후보를 선택하고, 데이터 품질을 이해하지 못한 채 코드를 생성합니다. 지난주 마이그레이션 버그로 `rating_score`에 30% null 비율이 발생한 열화된 테이블(`reviews.user_ratings_legacy`)을 사용하는 파이프라인이 배포될 수 있습니다.

#### DataSpoke와 함께

**1단계: 시맨틱 탐색**

```
AI 에이전트 쿼리: "ML 학습에 적합한 리뷰와 구매 테이블 찾기"

DataSpoke 응답 (via /api/v1/spoke/de/validator):
- reviews.user_ratings (✓ 품질 점수: 96)
  최근 갱신: 1시간 전 | 완전성: 99.7% | 28개 다운스트림 소비자

- reviews.user_ratings_legacy (⚠ 품질 문제)
  이상: 2024-02-03부터 rating_score에 30% null 비율
  권장: 사용 금지 — reviews.user_ratings 사용 권장

- orders.purchase_history (✓ 권장)
  SLA: 99.9% 정시 | 문서화: 100% | ML 사용 인증 완료
```

**2단계: 컨텍스트 검증**

```python
# POST /api/v1/spoke/de/validator/context
dataspoke.validator.verify_context("reviews.user_ratings_legacy")

# 응답:
{
  "status": "degraded",
  "quality_issues": [{
    "type": "null_rate_anomaly",
    "severity": "high",
    "message": "rating_score null 비율이 0.3%에서 30%로 급증",
    "recommendation": "reviews.user_ratings 사용 권장"
  }],
  "alternative_entities": ["reviews.user_ratings"]
}
```

**3단계: 파이프라인 검증**

```yaml
Pipeline: book_recommendations_daily_v1
Author: AI Agent (claude-sonnet-4.5)

검증 결과:
✓ 문서화: 설명 존재, data-science-team에 소유자 할당됨
✓ 네이밍 규칙: book_recommendation_features (준수)
✓ 품질 검사: NULL 처리 구현됨, 스키마 하위 호환
✓ 리니지 영향: 2개 업스트림 테이블 (모두 정상), 순환 의존성 없음
⚠ 권장사항: 데이터 신선도 검사 추가, 모니터링 알림 구현
```

**4단계**: AI 에이전트가 검증된 소스, 규정 준수 구조, 품질 검사를 갖추고 배포합니다.

#### DataHub 연동 포인트

Validator는 주로 **읽기** 소비자입니다. 여러 DataHub aspect를 조회하여 건강도 평가를 구성합니다:

| 검증 단계 | DataHub Aspect (읽기) | 반환 내용 |
|----------|---------------------|----------|
| 시맨틱 탐색 | `datasetProperties` | 설명, 태그 — 의미적 의도 매칭 |
| 품질 점수 | `datasetProfile` (시계열) | 행 수, null 비율 시계열 |
| 신선도 | `operation` (시계열) | `lastUpdatedTimestamp` |
| 다운스트림 수 | `upstreamLineage` (GraphQL) | 다운스트림 소비자 수 |
| 폐기 여부 | `deprecation` | `deprecated` 플래그, 대체 URN |
| 검증 이력 | `assertionRunEvent` (시계열) | 합격/실패 이력 |
| 스키마 검증 | `schemaMetadata` | 컬럼명, 타입 (네이밍 검사용) |

```python
graph = DataHubGraph(DatahubClientConfig(server=DATAHUB_GMS_URL, token=DATAHUB_TOKEN))
dataset_urn = "urn:li:dataset:(urn:li:dataPlatform:oracle,reviews.user_ratings_legacy,PROD)"

# 프로필 이력 — 이상 탐지를 위한 null 비율 시계열
profiles = graph.get_timeseries_values(dataset_urn, DatasetProfileClass, {}, limit=30)

# 최근 작업 — 신선도 확인
operations = graph.get_timeseries_values(dataset_urn, OperationClass, {}, limit=1)

# 업스트림 리니지 — 의존성 건강 여부
upstream = graph.get_aspect(dataset_urn, UpstreamLineageClass)
```

> **핵심 포인트**: DataHub는 수동적 데이터 저장소입니다. 원시 신호를 제공하며, DataSpoke가 품질 점수, 이상 탐지, 권장사항을 계산합니다.

#### DataSpoke 커스텀 구현

| 컴포넌트 | 책임 | DataHub가 할 수 없는 이유 |
|---------|------|------------------------|
| **품질 점수 엔진** | 프로필, assertion, 문서, 신선도 → 0–100 단일 점수 집계 | DataHub는 aspect 간 교차 점수 체계 없음 |
| **Null 비율 이상 탐지** | `datasetProfile` null 비율에 대한 시계열 분석 | DataHub는 프로필을 저장하지만 통계 분석 없음 |
| **대안 추천** | Qdrant에서 의미적으로 유사한 건강한 데이터셋 조회 | DataHub는 키워드 검색만 제공 |
| **파이프라인 검증 엔진** | 네이밍, 스키마 호환성, 리니지 영향 검증 | DataHub는 메타데이터를 저장하지만 그것에 대해 검증하지 않음 |
| **검증 결과 캐시** | 빠른 코딩 루프의 AI 에이전트를 위한 Redis 캐시 | DataHub에는 계산 결과에 대한 캐싱 없음 |

#### 결과

| 지표 | DataSpoke 없이 | DataSpoke와 함께 |
|-----|---------------|----------------|
| 파이프라인 실패율 | ~30% (불량 데이터) | <5% (사전 검증) |
| 사람 리뷰 시간 | 파이프라인당 수 시간 | 수 분 (자동화) |
| 데이터 품질 사고 | 빈번 | 거의 제로 |

---

### 유스케이스 3: Predictive SLA — 배송 파이프라인 조기 경보

**기능**: 온라인 데이터 검증기 (시계열 모니터링)

#### 시나리오: 배송 파트너 API 속도 제한이 주문 이행 대시보드를 위협

**배경:**
Imazon의 `orders.daily_fulfillment_summary` 테이블은 운영, 재무, 고객 지원 부서가 사용하는 물류 대시보드를 구동합니다. 이 테이블은 `orders.raw_events`, `shipping.carrier_status`, 그리고 외부 배송 파트너 API의 데이터를 집계하여 매일 오전 9시까지 150만 행을 처리합니다.

#### DataSpoke 없이

```
오전 9:00 — 알림: orders.daily_fulfillment_summary가 비어 있음
상태: SLA 위반 — 물류 대시보드 다운
대응: 수동 조사 시작. 오전 10:30에 근본 원인 발견 (배송 API 쓰로틀링).
총 다운타임: 2.5시간.
```

#### DataSpoke와 함께

**오전 7:00 — 조기 경보 (SLA 2시간 전):**

```
DataSpoke 예측 알림:
⚠ 이상: orders.daily_fulfillment_summary

오전 7시 현재 볼륨: 320K 행
예상 (평일 오전 7시): 900K ±5%
편차: -64% (3σ 임계값 초과)

업스트림 분석:
  orders.raw_events: ✓ 정상 (오전 6:30 기준 1.4M 행)
  shipping.carrier_status: ⚠ 40분 지연 (비정상)
    └─ 의존성: shipping_partner_api.tracking
       └─ 문제: API 속도 제한 초과 (429 응답)

근본 원인 (추정): 배송 파트너 API 쓰로틀링
예측: 오전 9시 SLA를 ~1.5시간 초과할 가능성

권장 조치:
  1. shipping_partner_api 속도 제한 확인
  2. logistics-eng에 API 할당량 문의
  3. 대안 고려: 마지막 성공 풀의 캐시된 배송사 데이터 사용

영향:
  - 물류 대시보드 (12명 — 운영팀)
  - 재무 일일 배송 리포트 (오전 9:30 자동 예약)
  - 고객 지원 SLA 트래커 (8명)
```

**오전 7:15** — 운영 엔지니어가 API 쓰로틀링을 확인하고 할당량 증가를 요청합니다. 파이프라인은 오전 8시에 복구됩니다. SLA를 1시간 여유로 충족합니다.

**2주차 — 패턴 학습:**

```
DataSpoke 인사이트: orders.daily_fulfillment_summary
패턴: 월요일 오전 7시 볼륨이 다른 평일 대비 지속적으로 -12% (4주 추세)
가설: 주말 주문 백로그가 월요일 아침 배치 지연 발생
자동 조정 임계값: 월요일 오전 7시: 790K ±5% (기존 900K에서 변경)
```

#### 결과

| 지표 | 기존 모니터링 | DataSpoke 예측 |
|-----|-------------|---------------|
| 탐지 시점 | 오전 9:00 (위반 후) | 오전 7:00 (위반 전) |
| 대응 시간 | 0분 (이미 늦음) | 120분 (선제적) |
| 비즈니스 영향 | 2.5시간 대시보드 다운 | 다운타임 제로 |
| 근본 원인 파악 | 90분 조사 | 2분 (자동 분석) |

---

### 유스케이스 4: Doc Suggestions — 인수 후 온톨로지 통합

**기능**: 자동 문서화 제안 (분류 체계/온톨로지 제안)

#### 시나리오: Imazon이 디지털 스타트업 "eBookNow"를 인수

**배경:**
Imazon이 디지털 전용 도서 플랫폼 eBookNow를 인수합니다. 합병 후 통합 DataHub 카탈로그에는 700개 이상의 데이터셋(eBookNow 200개 포함)이 있으며 개념이 중복됩니다. 6개 테이블이 "도서/상품"이라는 개념을 두 회사에 걸쳐 서로 다르게 표현합니다. 데이터 거버넌스 팀은 700개 데이터셋을 수동으로 감사할 수 없습니다.

#### DataSpoke 없이

```
개념: "도서 / 상품"

Imazon (레거시):
  - catalog.title_master          → isbn, title, author_id, list_price
  - catalog.editions              → edition_id, isbn, format, pub_date
  - inventory.book_stock          → isbn, warehouse_id, qty_on_hand

eBookNow (인수):
  - products.digital_catalog      → product_id, title, creator, price_usd
  - content.ebook_assets          → asset_id, product_ref, file_format
  - storefront.listing_items      → listing_id, item_name, seller_price

문제점:
  ✗ 6개 테이블이 서로 다른 스키마와 네이밍으로 "도서/상품"을 표현
  ✗ isbn과 product_id 간의 관계가 문서화되지 않음
  ✗ 다운스트림 파이프라인이 비일관적으로 조인
  ✗ 추천 엔진이 인쇄본과 디지털 모두 제공되는 타이틀을 이중 집계
```

#### DataSpoke와 함께

**1단계: 시맨틱 클러스터링**

```
DataSpoke Doc Suggestions — 시맨틱 클러스터링:

분석 대상: 700 데이터셋
감지된 시맨틱 클러스터: 38
충돌이 있는 클러스터: 9

클러스터: 도서 / 상품 (Critical)
동일 개념을 나타내는 6개 테이블 감지

유사도 매트릭스 (임베딩 코사인 거리):
  catalog.title_master   ←→ products.digital_catalog    0.93
  catalog.editions       ←→ content.ebook_assets         0.90
  inventory.book_stock   ←→ storefront.listing_items     0.86

근거:
  - 6개 모두 타이틀 유사 필드 포함 (100% 의미 매칭)
  - 6개 모두 가격 필드 포함 (95% 매칭)
  - 중복 다운스트림 리니지: 18개 공유 소비자
  - 샘플 레코드 중복 (추정): ISBN/타이틀 매칭 기준 72%
```

**2단계: 온톨로지 제안**

```
제안된 정규 엔티티: catalog.product_master

필드 (병합 스키마):
  - product_id          (대체키, 신규)
  - isbn                (nullable — 디지털 전용 타이틀은 ISBN 없음)
  - title               (정규화)
  - format              (enum: print | ebook | audiobook)
  - source_system       ("imazon" | "ebooknow")
  - legacy_isbn         (catalog.title_master.isbn에 매핑)
  - legacy_product_id   (products.digital_catalog.product_id에 매핑)
  - list_price          (USD로 정규화)
  - publication_date

제안된 테이블 역할:
  catalog.product_master        → 신규 정규 SSOT
  catalog.title_master          → 인쇄본 뷰 (유지, 정규 테이블에 별칭)
  catalog.editions              → 에디션 상세 뷰 (유지)
  products.digital_catalog      → 폐기 → 정규 테이블로 마이그레이션
  content.ebook_assets          → 디지털 자산 뷰 (유지)
  inventory.book_stock          → 재고 뷰 (유지)
  storefront.listing_items      → 폐기 → 정규 테이블로 마이그레이션

일관성 규칙:
  R1. 새 파이프라인은 반드시 catalog.product_master로 조인
  R2. title 정규화: TRIM + title-case
  R3. product_id는 할당 후 불변
  R4. 도서 기원 이벤트에 source_system 태그 필수

영향: 18개 파이프라인 업데이트 필요 | 난이도: 중간 (스키마 추가 방식)
```

**3단계: 주간 일관성 검사** — DataSpoke가 규칙 위반을 스캔합니다. 예시: 새 파이프라인이 `catalog.product_master` 대신 `products.digital_catalog`로 조인하여 인쇄 전용 타이틀의 60%가 추천에서 제외됨. 92% 신뢰도로 자동 수정 제안.

#### 결과

| 지표 | 수동 통합 | DataSpoke Doc Suggestions |
|-----|---------|---------------------------|
| 제안까지 소요 시간 | ~3개월 (수동 감사) | 수 시간 (자동 클러스터링) |
| 카탈로그 AI 준비도 | 58% | 91% |
| 월간 위반 건수 | 미추적 | 2–3건 (자동 감지) |

---

## 데이터 분석(DA) 그룹

### 유스케이스 5: NL Search — GDPR 컴플라이언스 감사

**기능**: 자연어 검색

#### 시나리오: 법무팀이 마케팅에서 사용하는 유럽 고객 PII를 검색

**배경:**
Imazon 법무팀이 GDPR 감사를 준비하며 다음을 요청합니다: "마케팅 분석 파이프라인에서 접근하는 유럽 고객 PII가 포함된 모든 테이블을 찾아주세요." 이는 PII 분류, 지리적 범위, 리니지를 교차 참조해야 하며 — 키워드 검색으로는 처리할 수 없는 다차원 쿼리입니다.

#### DataSpoke 없이

수동 프로세스: DataHub에서 "customer" 테이블 검색, 각 설명에서 "EU"/"Europe" 확인, 컬럼명에서 `email`/`name`/`address` 검색, 마케팅 소비자까지 수동으로 리니지 추적, 50개 이상 테이블 검토. **소요 시간: 4–6시간. 정확도: ~70%** (문서화 품질에 따라 다름).

#### DataSpoke와 함께

**쿼리:**

```
자연어 입력 (via /api/v1/spoke/da/search):
"마케팅 분석에서 사용하는 유럽 고객 PII가 있는 테이블 찾기"
```

**응답 (2.3초):**

```
7개 테이블 매칭 결과

높은 우선순위 (직접 PII + 마케팅 사용)

1. customers.eu_profiles (관련도: 98%)
   PII 필드: email, full_name, shipping_address, date_of_birth
   지역 태그: EU/GDPR
   마케팅 리니지:
     └─ marketing.eu_email_campaigns (활성)
        └─ dashboards.eu_campaign_performance
   컴플라이언스: ✓ 보존: 2년 | ✓ 암호화: at-rest + transit
               ⚠ 삭제권: 수동 프로세스

2. orders.eu_purchase_history (관련도: 94%)
   PII 필드: customer_id (연결 가능), shipping_address, payment_last4
   마케팅 리니지:
     └─ marketing.eu_buyer_segmentation
        └─ recommendations.eu_personalized_picks
   컴플라이언스: ✓ 90일 후 익명화 | ✓ GDPR 보존 준수

중간 우선순위 (파생 / 가명화)

3. marketing.eu_reader_segments (관련도: 87%)
   PII 필드: hashed_email, aggregate_reading_score
   업스트림 PII: customers.eu_profiles (1 홉)
   활성 캠페인: 8 | 대시보드 의존: 4

[... 4개 테이블 추가 ...]

요약:
  직접 PII 테이블: 2 | 파생 PII 테이블: 5
  활성 마케팅 파이프라인: 11
  GDPR 컴플라이언스 격차: 1 (삭제권 자동화)
```

**후속 질문:** "자동 삭제권이 없는 테이블은?" → DataSpoke가 `customers.eu_profiles` (수동 SQL 필요)와 `reviews.eu_book_reviews_archive` (콜드 스토리지, 48시간 복원)를 식별합니다. 자동 삭제 작업을 권장합니다.

#### 결과

| 지표 | 기존 검색 | DataSpoke NL Search |
|-----|---------|---------------------|
| 시간 | 4–6시간 | 2–5분 |
| 정확도 | ~70% | ~98% |
| 후속 질문 | 처음부터 다시 | 대화형 정제 |
| 감사 보고서 | 수동 작성 | 자동 생성 |

---

## 데이터 거버넌스(DG) 그룹

### 유스케이스 6: Metrics Dashboard — 전사 메타데이터 건강도

**기능**: 전사 메트릭 시계열 모니터링

#### 시나리오: CDO가 6개 부서에 걸쳐 메타데이터 건강도 이니셔티브 시작

**배경:**
Imazon의 CDO(Chief Data Officer)가 데이터 문서화와 소유권 책임을 개선하기 위한 전사 이니셔티브를 시작합니다. 6개 부서가 400개 이상의 데이터셋을 관리하지만, 문서화 커버리지와 소유권 할당은 부서마다 크게 다릅니다. 거버넌스 팀은 현재 2주가 걸리는 분기별 수동 감사를 수행하며, 작성 즉시 낡아버리는 시점별 스프레드시트를 생성합니다.

#### DataSpoke 없이

수동 감사 사이클: 거버넌스 팀이 테이블을 검토하고, 추적 스프레드시트를 만들고, 부서 리드에게 이메일을 보내고, 2주 후 후속 조치하고, 분기별로 반복합니다. **문제점:** 노동 집약적 (감사당 2주), 시점별 스냅샷, 자동 추적 없음, 개선 측정 어려움.

#### DataSpoke와 함께

**1주차 — 초기 평가:**

```
DataSpoke 메트릭 대시보드:
전사 메타데이터 건강도 점수: 59/100

부서별 현황:
┌─────────────────────┬────────┬──────────┬────────┬─────────┐
│ 부서                │ 점수   │ 데이터셋 │ 이슈   │ 추세    │
├─────────────────────┼────────┼──────────┼────────┼─────────┤
│ 엔지니어링          │ 76/100 │ 95       │ 23     │ ↑ +3%   │
│ 데이터 사이언스      │ 69/100 │ 72       │ 22     │ → 0%    │
│ 마케팅              │ 54/100 │ 80       │ 37     │ ↓ -2%   │
│ 재무                │ 81/100 │ 38       │ 7      │ ↑ +5%   │
│ 운영                │ 45/100 │ 65       │ 36     │ → 0%    │
│ 출판사 관계          │ 40/100 │ 55       │ 33     │ ↓ -1%   │
└─────────────────────┴────────┴──────────┴────────┴─────────┘

Critical 이슈: 42 | High: 78 | Medium: 118
```

**상세 뷰 — 마케팅:**

```
마케팅 부서 — 점수: 54/100 (목표: 70)

Critical (12 데이터셋):
  - 사용량 높은 테이블에 소유자 누락
  - marketing.campaign_metrics_daily에 설명 없음 (38명의 다운스트림 사용자!)

자동 생성 조치 항목 → marketing-data-lead@imazon.com:
  우선순위 1 (기한: 1주):
  [ ] marketing.campaign_metrics_daily에 소유자 할당
  [ ] 사용량 상위 5개 미문서화 테이블에 설명 추가
  우선순위 2 (기한: 2주):
  [ ] 고객 대면 테이블에 PII 분류 추가
  [ ] 모든 메트릭 테이블의 갱신 주기 문서화
```

**2주차 — 자동 알림** — DataSpoke가 데이터셋 소유자에게 구체적인 조치 항목, 예상 수정 시간 (~5–10분), 예상 점수 영향을 이메일로 발송합니다.

**1개월차 — 진행 상황:**

```
전사 건강도 점수: 59 → 70 (+11포인트)

최다 개선: 마케팅 54 → 71 (+17) — 이달의 부서
  35/37 critical 이슈 해결 | 평균 대응: 3일 (기존 12일)

주의 필요: 출판사 관계 40 → 44 (+4) — 목표 속도 미달
  권장: 팀 리드와 1:1 미팅 예약

지표:
  문서화 커버리지: 64% → 78% (+14%)
  소유자 할당률: 79% → 93% (+14%)
  평균 이슈 해결: 4.1일 (목표: 5일) ✓
```

**3개월차 — 마일스톤:** 전사 점수 77/100 도달 (목표: 70). 모든 부서가 최소 임계값 초과. 문서화 감쇠율 -2.1%/월 추적 (새 테이블 생성이 문서화보다 빠름). DataSpoke가 새 테이블 생성 시 필수 문서화 체크리스트를 권장합니다.

#### 결과

| 지표 | 분기별 수동 감사 | DataSpoke 메트릭 대시보드 |
|-----|---------------|------------------------|
| 감사 주기 | 2주, 분기별 | 실시간, 상시 |
| 이슈 대응 시간 | 평균 12일 | 평균 3일 |
| 건강도 점수 개선 | 미측정 | 3개월 만에 59 → 77 |
| 거버넌스 팀 노력 | 100% 수동 | 80% 절감 |

---

## 요약: 전달 가치

| 유스케이스 | 사용자 그룹 | 기능 | 기존 방식 | DataSpoke와 함께 | 개선 효과 |
|-----------|-----------|------|---------|----------------|----------|
| **레거시 도서 카탈로그 보강** | DE | Deep Ingestion | 수동 메타데이터 입력, 리니지 없음 | 자동 다중 소스 보강 | 89% 보강, 210개 리니지 엣지 |
| **추천 파이프라인 검증** | DE / DA | Online Validator | ~30% 실패율 (불량 데이터) | <5% 실패 (사전 검증) | 사고 83% 감소 |
| **배송 SLA 조기 경보** | DE | Online Validator | 위반 후 사후 알림 | 2시간 이상 사전 예측 경보 | SLA 위반 제로 |
| **인수 후 온톨로지** | DE | Doc Suggestions | 3개월 수동 통합 | 수 시간 내 자동 제안 | 수십 배 빠름 |
| **GDPR 컴플라이언스 감사** | DA | NL Search | 4–6시간 수동 검색 | 2–5분 자동 검색 | 98% 시간 절약 |
| **전사 메타데이터 건강도** | DG | Metrics Dashboard | 분기별 수동 감사 | 실시간 상시 모니터링 | 80% 효율 향상 |

**공통 이점:**
- **AI 준비 완료:** 자율 에이전트가 Imazon의 프로덕션 데이터와 안전하게 작업 가능
- **실시간 인텔리전스:** 사후 대응에서 선제적 데이터 관리로 전환
- **컨텍스트 인식:** 모든 부서에 걸쳐 데이터 관계와 비즈니스 의미를 이해
- **측정 가능한 영향:** 품질, 컴플라이언스, 효율성의 정량적 개선
- **온톨로지 건강:** 인수와 유기적 성장을 통해서도 카탈로그의 의미적 일관성 유지
