# Testing depth (JUnit 5 + slices + Testcontainers)

SKILL.md has the slice table, `@MockitoBean`, the `@WebMvcTest` example, and the
`@ServiceConnection` snippet. This is the depth: when each slice earns its cost, container
reuse, the modern test clients, `@DataJpaTest` patterns, and a CI gate.

## Slice selection (cost vs coverage)

- **`@WebMvcTest(Foo.class)`** — loads only that controller, Bean Validation, Jackson, and
  Spring Security. Milliseconds. Supply collaborators with `@MockitoBean`. Use for: status
  codes, validation errors, JSON shape, auth rules.
- **`@DataJpaTest`** — loads JPA + a database, wraps each test in a transaction it rolls back.
  Use for: derived queries, `@Query` correctness, mappings, fetch behavior. Point it at a real
  Postgres via Testcontainers (below) rather than H2, so dialect differences don't hide bugs.
- **`@SpringBootTest`** — full context; slowest. Use only for genuine end-to-end paths
  (controller -> service -> real repo -> DB). Add `webEnvironment = RANDOM_PORT` + `WebTestClient`
  for real HTTP.

Reach down this list only when the cheaper slice can't express the assertion.

## Mocking — `@MockitoBean`, not `@MockBean`

`@MockBean`/`@SpyBean` are removed in Boot 4. Use `@MockitoBean`/`@MockitoSpyBean` from
`org.springframework.test.context.bean.override.mockito`. They replace the matching bean in
the context for that test class.

```java
@WebMvcTest(UserController.class)
class UserControllerTest {
    @Autowired MockMvc mvc;
    @MockitoBean UserService users;

    @Test void returns201() throws Exception {
        when(users.create(any())).thenReturn(new UserResponse(1L, "Ada", "ada@x.io"));
        mvc.perform(post("/api/users").contentType(APPLICATION_JSON)
                .content("{\"name\":\"Ada\",\"email\":\"ada@x.io\"}"))
           .andExpect(status().isCreated())
           .andExpect(header().string("Location", "/api/users/1"));
    }
}
```

`MockMvcTester` (Boot 4, AssertJ-style) is the more fluent alternative to raw `MockMvc` for
new tests; `WebTestClient` is the choice for real-port `@SpringBootTest`.

## Testcontainers + `@ServiceConnection`

A container `@Bean` annotated `@ServiceConnection` registers its `ConnectionDetails`
automatically — Spring points the datasource at the container with no `@DynamicPropertySource`.

```java
@TestConfiguration(proxyBeanMethods = false)
class ContainersConfig {
    @Bean @ServiceConnection
    PostgreSQLContainer<?> postgres() { return new PostgreSQLContainer<>("postgres:17"); }
}

@DataJpaTest
@Import(ContainersConfig.class)
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)  // use the real container
class UserRepositoryTest {
    @Autowired UserRepository repo;
    @Test void findsByEmail() { /* save + assert */ }
}
```

Speed local runs with reuse — survives across test JVMs:

```text
# ~/.testcontainers.properties
testcontainers.reuse.enable=true
```

…and `new PostgreSQLContainer<>("postgres:17").withReuse(true)`. (Reuse is a local convenience;
CI usually starts fresh containers per run.)

## `@DataJpaTest` patterns

- **Test-data builders** beat hand-built entity graphs: a `users().withEmail(...).build()`
  helper keeps tests readable and tolerant of new required fields.
- Use `TestEntityManager` to persist + `flush()` + `clear()` before asserting a query, so you
  read from the DB, not the first-level cache.
- Each test rolls back by default — don't assert across tests or rely on insertion order.

## CI gate

Wire the build's test phase plus this skill's static reviewer:

```bash
./mvnw -q verify          # compile + unit + slice + integration tests (or ./gradlew check)
./scripts/verify.sh src   # flag legacy Spring idioms (WebSecurityConfigurerAdapter, @MockBean, javax.*, …)
```

Run real integration tests behind a tag/profile so the fast slices give quick feedback and the
container-backed tests run on the gate.
