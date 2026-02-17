# API Design Principle

This document outlines several specific principles related to REST API design, particularly URI structure. These principles apply to all APIs developed in this project.

---

## 1. Standard Request & Response Formats

### 1. Basic Guide

All requests must follow these standards so the server can accurately identify and process resources.

- **Declare Content-Type:** Include the `Content-Type: application/json` header on all write requests (POST, PUT, PATCH).
- **UTF-8 Encoding:** Always use UTF-8 encoding to prevent data corruption.
- **Field Naming Convention:** Request body field names must be consistent, just like URIs (e.g., choose either `snake_case` or `camelCase` as the team standard).
- **Date/Time Format:** Use the ISO 8601 standard (`YYYY-MM-DDTHH:mm:ssZ`) to avoid timezone confusion.

### 2. Response Format Guide

Responses must be structured so clients can immediately determine success and easily parse the data.

- **Use HTTP Status Codes:** Convey the response status via appropriate HTTP status codes (200 OK, 201 Created, 400 Bad Request, 404 Not Found, etc.) rather than embedding it only in the JSON body.
- **Standardize Error Responses:** Return a consistent error object when an error occurs.
  - e.g., `{"error_code": "INVALID_PARAMETER", "message": "The 'count' field must be an integer."}`

### 3. Separation of Content and Metadata

Within the response body, clearly separate the **data the client actually requested (Content)** from the **information used for system processing (Metadata)**. This allows clients to handle the core data model and supplementary information independently.

- **Content (requested data):** The resource data that is central to the business logic.
- **Metadata:** Includes pagination info, response time, API version, trace ID, etc.

#### Best Practice Example

When requesting a list of fruits, this example separates the `fruits` resource from all other control information.

```json
{
    // Content: the requested resource data (list response for a plural-form path)
    "fruits": [
         {"name": "apple", "count": 5},
         {"name": "banana", "count": 3}
    ],

    // Metadata: control and supplementary information
    "offset": 5,
    "limit": 2,
    "total_count": 30,
    "resp_time": "2026-01-01T13:14:15.123+09:00"
}
```

---

## 2. Standard URI Structure

### 1. Resources must always use noun forms

URIs should focus on "What". The verb — "How" — is handled by the HTTP method.

- **Bad (Action-based):**
  - `POST /createNewUser`
  - `GET /get_order_list`
  - `DELETE /delete-post/42`

- **Good (Resource-based):**
  - `POST /users` (create a user)
  - `GET /orders` (retrieve order list)
  - `DELETE /posts/42` (delete post #42)

---

### 2. Follow the Classifier / Identifier structure

Use a hierarchical structure to clearly distinguish a resource's parent scope from its identifier.

- **Structure:** `/{classifier}/{identifier}/{sub-classifier}/{identifier}`
- **Example (e-commerce review system):**
  - `/products` (full product list)
  - `/products/p001` (the specific product with ID p001)
  - `/products/p001/reviews` (all reviews for product p001)
  - `/products/p001/reviews/rev99` (the specific review with ID rev99 under product p001)

---

### 3. A plural-form path must return a list (Collection) response

When a path ends in a plural form (`.../s`), clients must always be able to expect an array (`[]`) response.

- **Example (payment history):**
  - `GET /payments`
  - **Response (List):**
    ```json
    [
      { "pay_id": "T01", "amount": 5000 },
      { "pay_id": "T02", "amount": 12000 }
    ]
    ```

- **Contrast:** `GET /payments/T01` (returns a single object `{ "pay_id": "T01", ... }`)

---

### 4. Use Meta-Classifiers (attrs, methods, events)

The purpose of this principle is to clearly separate plain data fields (Field), business logic (Action), and state changes (History), making the nature of each API self-evident.

A meta-classifier placed after a resource identifier acts as a signpost, defining what kind of data the API is working with.

#### 1. attrs (Attributes): Separating state and configuration

Use this when you want to read or update only a specific group of attributes — such as **metadata, configuration values, or permission states** — rather than fetching the entire resource object. This reduces the overhead of transferring heavy objects in full.

- **Example (user settings):**
  - `GET /members/m_123/attrs` : Retrieve only 'attribute' fields such as profile photo, marketing consent, and language preference.
  - `PATCH /members/m_123/attrs` : Update only a specific attribute (e.g., enabling dark mode).

- **Example (device state):**
  - `GET /iot-devices/dev_88/attrs` : Check dynamic attribute values such as current temperature, battery level, and connection status.

#### 2. methods (Functional Actions): Business logic beyond simple CRUD

REST fundamentally deals with resource state, but real-world services have complex business processes — such as **approval, recovery, or dispatch** — that are hard to express as simple field updates. Placing these after `methods` makes the intended action explicit.

- **Example (payment and order process):**
  - `POST /payments/pay_abc/methods/approve` : Execute payment approval logic.
  - `POST /orders/ord_555/methods/calculate-tax` : Invoke tax calculation logic (returns the result only).

- **Example (account security):**
  - `POST /accounts/u_789/methods/lock` : Force-lock an account due to a security threat.
  - `POST /accounts/u_789/methods/unlock` : Unlock an account after identity verification.

#### 3. events (Lifecycle & Audit Logs): State changes over time

Resources change over time. Use `events` to track the **history of occurrences** on a specific resource; it is primarily used as read-only.

- **Example (delivery tracking):**
  - `GET /deliveries/deliv_99/events` : Retrieve the full timeline log: [Picked up -> Hub arrived -> Out for delivery -> Delivered].

- **Example (document change history):**
  - `GET /documents/doc_001/events` : Audit log of who modified or accessed this document and when.

- **Example (error log):**
  - `GET /servers/srv_10/events` : History of system events and errors that occurred on the server.

---

### 5. URL Query Segments are for filtering and sorting

Use query parameters to change how data is presented while keeping the resource's canonical path intact.

- **Filtering:**
  - `/tickets?status=open&priority=high` (return only open, high-priority tickets)

- **Sorting:**
  - `/products?sort=price_asc` (sort by price, ascending)

- **Pagination:**
  - `/logs?offset=20&limit=10` (retrieve 10 entries starting from the 21st)
