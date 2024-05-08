API Flows
=========

General Patterns
----------------

- Authenticated requests use a JWT header using HMAC256 signing for authentication
-- Authentication may be bidirectional: responses may be signed depending on the endpoint
-- The JWT includes the following signed claims
--- The sending node ID (iss)
--- The receiving node ID (aud)
--- A unique auth id (sub)
--- A signature of the payload (sig)
---- SHA256 of control payloads
---- MD5 of data payloads
----- Performance compromise: Reuse of an established signature from earlier in the flow.
------ TODO: Per https://security.stackexchange.com/questions/95696/which-hash-algorithm-takes-longer-time-if-we-compare-between-md5-or-sha256 md5 may be *slower*
-- Symmetric keys are used:
--- For the cluster key both ends need to know the secret as all nodes are equal in the cluster, so no benefit to symmetric signing and a serious configuration penalty (The HMAC secret can be any random string).
--- Session auth will be relatively high volume signing, so the lower computational overhead of symmetric keys is desirable.
--- Using the same algorithm for cluster and session auth reduces code complexity.

Common Structures
-----------------

### Node Info

The node info is the base information unique to the node.
It contains:

- The node ID: A randomly generated UUID identifying the unique node instance.  This ID is generated on startup and static for the life of the process
- The node listen URL (advertise URL in the config)
- The node network address CIDRs: CIDR addresses of the mesh subnets routed
- The node unique address CIDRs: CIDR addresses unique to the node

Node ID is used to identify unique nodes within the mesh, and is heavily used internally as a unique key.

The listen URL is used to allow nodes to discover other nodes in the mesh through existing registrations.
This allows the mesh to grow without relying on external service discovery.
If a node can register to any node in the mesh the registration will propagate to all nodes.

The addresses are used to enable traffic routing within the cluster.

### Registration Payload

The registration payload is a very common structure, used in several flows and variations.
This structure is the base of the mesh, it is how nodes know about other nodes.

The structure contains:

- Local node info: This is a Node Info structure.
- A list of Node Info structures for all registered remote nodes
- A Unix stamp

The local node info is the primary payload, it is used by the receiving side to set up the data structures needed to route traffic.
The remote node list is used to maintain the mesh, if a node receives a registration with a unknown remote node it will register to the unknown remote node to ensure the mesh is not missing a route.
The Unix stamp is used for grooming to remove stale registrations.
Nodes are expected to re-register regularly and often.

Flow Diagrams
=============

Initial Registration Flow
--------------------------

This diagrams shows the API Calls of a new node (N) registering into an existing node (E).

At the beginning of this flow N knows a URL to access E, either via bootstrap config or from another node.
The URL may be load balanced and not direct, depending on the bootstrap configuration.

This flow uses cluster auth as it is the first interaction between unknown nodes.
The registration step is important to happen early as the internal data structures needed for session auth are created by this flow.

```
                              N                                                            E
                              |                                                            |
                              | (1) N request's node_info from E via initial URL           |
                   START ---  | --------[ Potential NAT and/or load balancing ]-------->   |
                              | GET tunmesh/control/v0/node_info (No Auth)                 |
                              |                                                            | Stateless operation on E
                              |                                                            | Returning static, non-sensitive data
N Updates internal datastores |                                                            |
with response ID and          |                           (2) responds with a JSON payload |
listen URL   +--------------- |   <------------------------------------------------------- |
             |                |                                                            |
             |                |                                                            |
             |                | (3) N sends a registration POST using cluster auth         |
             |                |       to the listen_url in (2)                             |  
             +--------------> | ------------------------------------------------------->   | ----+  E initializes the internal
                              | POST /tunmesh/control/v0/registrations/register (Cluster)  |     |  data structures for interacting
                              |                                                            |     |  with N, and can now negotiate
                              |                                                            |     |  a session and route traffic.
N initializes the internal    |   (4) E responds with its own registration payload         |     |
data structures for E,        |       causing mutual registration.  The response           |     |
and can now negotiate         |       is also signed with the cluster token.               |     |
a session             END --- |   <------------------------------------------------------- | ----+
and route traffic.            |                                                            |
This completes the            |                                                            |
registration flow.            |                                                            |
```

### Detailed steps

#### 1 & 2: tunmesh/control/v0/node_info

The first request is a unauthenticated GET to the target node to get required information about the remote node.
The tunmesh/control/v0/node_info endpoint is a unauthenticated GET endpoint that returns:

- The node ID: A randomly generated UUID identifying the unique node instance.  This ID is generated on startup and static for the life of the process
- The node listen URL

This is a subset of the registration payload, unsigned as the request was unauthed.

The node ID is needed as this is the unique identifier within the cluster used to track the other nodes.
The node ID is used in signing auth requests, so without the remote node ID no authenticated requests can be made.
As the node ID is dynamic and process unique it must be gathered from the remote end when unknown.
The ID is not sensitive and is exposed via logs, open endpoints, and monitoring metrics.

The listen URL is sent to support bootstrapping over load balancers.
The API protocol is designed for point to point VPN links, each node needs to be able to communicate direct with targeted remote nodes.
As such the protocol design is incompatible with load balancing: the auth signing, session handling, and general packet routing requires all requests to a given URL to go to a single, unique node for that URL.
However, there are valid cases for using a load balancer for bootstrapping, such as when creating a mesh across multiple clusters.
Returning the listen URL allows the requesting node to discover the real listen address of a node in the cluster and use the direct URL for all subsequent requests.

#### 3: Initial Registration

This request is a POST to register node N into node E.
This request contains a Registration Payload.

This request is signed using the cluster token, which is the root of trust within the cluster.
A session token is not used as, until a registration is accepted, the receiving node does not have a structure initialized to maintain the session details.
Sessions are internally tied to registrations, which is a design decision made as registrations are groomed and old registrations purged.
Tracking sessions independently of registrations was not done as that would require more groomers and work to ensure they stay in sync with registrations.

Upon receiving the registration and validating the signature E initializes the internal registration structure with details about N.
At this point E can accept session auth requests from N, traffic from N, and will begin attempting to route packets to N.

#### 4: Registration of E into N

E responds with its own Registration Payload in the POST response to form a mutual registration.
The response is also signed with the cluster token, so N can validate that the registration is trusted.

Upon receiving the response and validating the signature N initializes the internal registration structure with details about E.
At this point N can accept session auth requests from E, traffic from E, and will begin attempting to route packets to E.

### Attack Vectors

- No protection provided by TLS at this phase
-- The server requires TLS, but does not verify as the CN will not match the dynamic address
--- TODO: Can we improve this?
--- TODO: Open to eavesdropping

#### 1 & 2: tunmesh/control/v0/node_info request

This is a open and unauthenticated request, at a point in the flow where nodes N and E have no established sessions or trust.
This request is open to attack if an attacker can intercept a bootstrap request.

An attacker could return a poisoned payload to an attacker controlled listen URL.

#### 3: Initial Registration

Assuming an attacker poisoned the response in 2 to a attacker controlled URL the server will send a post to a malicious URL.

This payload will contain the registration details, which is considered nonsensitive and, as of 2024-05-07 / v0.5.12 returned via an opened endpoint.

The payload will be signed with the cluster token.
The signing is (as of 2024-05-07 / v0.5.12) HMAC256 so the signing is non-reversible.

Gaining access to the signing JWT could be used to gather material to crack the cluster token, but it does not expose the cluster token by itself.

#### 4: Registration POST response

At this point the attacker can return their own registration payload to form the mutual registration.

This response is expected to be signed by the cluster token, which the attacker does not possess.
(Compromise of the cluster token is compromise of the cluster, as the cluster token is the root of trust.)
The response will fail signature validation and N will reject the response.

The rejection will stop the process before N initializes the internal node data of the malicious node, so N will not attempt to route traffic or establish session auth to the malicious node.

Registration Renewal Flow
--------------------------

This diagrams shows the API Calls of a established node (A) re-registering into an existing node (B).

This flow is almost the same as the initial registration, except B's node_data is already known and session auth will be used instead of cluster auth.
Session Auth setup is documented in `Session Auth Request` below.

If the node is unable to register with session auth it may fall back to cluster auth, in which case the flow is the same just with the same URL and auth as initial registration steps 3 & 4.

```
                              A                                                            B
                              |                                                            |
                              | (1) A sends a registration POST using session auth         |
                              |     to the listen_url advertised in previous registrations |  
                   START ---  | ------------------------------------------------------->   | ----+  B updates its internal data
                              | POST /tunmesh/control/v0/registrations/register/[ID]       |     |    structures as needed.
                              |      (Session Auth: A -> B)                                |     |
                              |                                                            |     |
                              |                                                            |     |
A updates its internal        |   (2) B responds with its own registration payload         |     |
data structures for B         |       causing mutual registration.  The response           |     |
                              |       is signed with B's session auth to A.                |     |
                      END --- |   <------------------------------------------------------- | ----+
                              |                                                            |
                              |                                                            |
```

### Detailed steps

#### 1: A -> B Re-Registration request

This request is a unsolicited POST to register node A into node B, triggered on a timer.
This request contains a Registration Payload.

This request is signed using a pre-negotiated session token.
If the request fails with a error that A is not known to B then A will fall back to cluster auth, repeating steps 3 and 4 of the initial registration flow.

Upon receiving the registration and validating the signature B updates it's internal data about B as needed.

#### 2: B -> A Re-registration

B responds with its own Registration Payload in the POST response to form a mutual registration.
The response is signed with B's session token to A, so A can validate that the registration is trusted.

If this response fails validation then A will retry the flow.

### Attack Vectors

#### 1: A -> B Re-Registration request

This channel is harder to attack than the initial flow as A and B have already established trusted connections and session auth.
A sends the request direct to the known URL for B, so to redirect the request to a malicious node the registration would need to be pre-poisoned.
The session token is random, rotated every hour by default, and only exists in memory.

It could be possible for an attacker to force a shift from session auth to cluster auth, but this is logged at the WARN level.
Shifting from session to cluster does not open any impersonation vectors.

TODO: MITM eavesdropping protection

#### 2: Registration POST response

This response is signed with B's session token.
If the token is not correct A will reject the payload and continue to use the previous data.

Session Auth Request
---------------------

This diagrams shows the API Calls of a receiving (R) node negotiating session auth with a generating node (G).

This flow can be initiated by the following triggers:

- R has a packet to route to G, but has not yet established a session
- R needs to refresh its registration and the session auth is 
- A session auth fault triggering renegotiation

This flow requires G and R to be registered to each other.

Session auth is symmetric, but is only used for traffic in one direction.
The unidirectional usage is done to reduce potential race conditions.

The session secret is encrypted in transit internally.
This entire flow is protected by the server TLS layer, but due to this flow sending essentially a password over the wire an additional encrypt step was added so that secrets are never sent in the clear.

As this flow is not directly triggered by the registration process R and G do not map to N and E in the registration flow, the roles may be reversed.

This flow uses session auth if established, or cluster auth if not.

```
                              R                                                            G
                              |                                                            |
                              | (1) R requests new session auth secret, sending            |
                              |        it's public key.                                    |
                    START --- | -------------------------------------------------------->  | ---+ G validates the auth token sent in the request.
                              | POST /tunmesh/auth/v0/init_session      (Cluster auth)     |    | G then generates a new shared session secret,
                              | POST /tunmesh/auth/v0/init_session/[ID] (Session Auth)     |    |   and encrypts it with the public key in the request.
                              |                                                            |    | G replaces its internal R to G auth token with a new token
                              |                                                            |    |   using the new secret, and returns the encrypted secret.
G decrypts the secret         |             (2) G replies with the encrypted shares secret |    |
and updates its       END --- |  <-------------------------------------------------------- | ---+
R to G token.                 |                        (Same auth pattern as the request)  |
                              |                                                            |
                              |                                                            |
```

### Detailed steps

#### 1: A -> B session init request

This request is a unsolicited POST to create or rotate the session auth R uses when sending to G.
This request contains a RSA public key, 2048 bits by default.
This key is unique to R and generated on process start.

This request is signed by R as authentication only, this request is not sensitive.

If an attacker was able to replace the RSA public key they would not be able to impersonate G as G does not use the session secret generated here to auth to R.
If an attacker replaced the RSA key in the request and replayed it to R the transaction would fail as R would not be able to decrypt the secret with the original private key.
This attack is additionally impractical as tampering with the payload will cause the JWT validation to fail.

If an attacker is able to impersonate a session token they could use this flow to generate new session tokens.
However, as the attack request would cause G to update it's R -> G session token for R, but R would not be updated, the next request from R would trigger a failure and a renegotiation.
For a impersonation attack to work the attacker would need to trigger a request, and complete step 2, and be able to crack the asymmetric key encrypting the actual key.

### 2: B -> A encrypted secret response

This is the response to the session request in step 1.

This request is signed by G.
The auth used depends on the request auth.
If R uses session auth the G will also use session auth.
If R uses cluster auth G will use cluster auth.

As this is a response to an established connection injecting data will be very difficult.

A MITM attack is impractical as the response is both signed with a JWT token and the response is encrypted with R's private key.
To MITM this leg of the flow an attacker would need to compromise both G to R's session token and R's RSA key.

This request is resilient to eavesdropping due to the internal encryption in use, beyond the outer API TLS encryption.

Packet TX
---------

This diagrams shows the API Calls of a transmitting (T) node sending a packet to a receiving (R) node.

This flow is initiated by T receiving a packet over the tun device destined for R.

This flow requires G and R to be registered to each other.
This flow requires T -> R session auth.

```
                              T                                                            R
                              |                                                            |
                              | (1) T makes a post request to R with the packet payload    | 
                    START --- | -------------------------------------------------------->  | ---+ R validates the auth token sent in the request.
                              | POST /tunmesh/control/v0/packet/rx/[ID] (Session Auth)     |    | Once validated the packet is accepted for final
                              |                                                            |    |   checks and transmission on the local tun device.
                              |                                                            |    |   
T logs any errors.            |                           (2) R replies with an empty 204  |    |
                      END --- |  <-------------------------------------------------------- | ---+
                              |                                      (No auth: no content) |
                              |                                                            |
                              |                                                            |
```

#### 1: T -> R packet transmission 

This request is a unsolicited POST to transmit a packet.
This request contains the contents of a tunneled network packet.

This request is signed using a pre-negotiated session token.
Cluster auth is not supported.

If there is a fault the packet is dropped, and left to the app generating the traffic to retry.

#### 2: R -> T packet response

This is a HTTP 204 with no body, except on auth error where `4XX` errors will be returned.

This response is unsigned as there is nothing to sign.
A `4XX` error may force a session renegotiation but otherwise T takes no action based on the response.

### Attack Vectors

#### 1: T -> R packet transmission

This request is protected by the session token which is used both to show that the packet came from T and was not tampered with.
If an attacker is able to compromise a session token they can inject traffic into the container stack on R.

Routing from the tunnel out of the container stack is not supported.
Malicious packets not destined for the local tunnel IP will be blocked and logged by G.

TODO: MITM eavesdropping protection

#### 2: Registration POST response

This response is empty and T takes no action based on it.

If a MITM attack was able to modify the responses the scope is limited to forcing a session auth renegotiation by faking a 4XX error.
