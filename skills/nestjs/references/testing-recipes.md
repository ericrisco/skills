# Testing recipes

The Nest-specific harness. For generic JS/TS test craft (runner config, coverage gates), that is `../../testing-web/SKILL.md`.

## The harness

`Test.createTestingModule({...})` builds a module exactly like a real `@Module`, then `.compile()` resolves it into a `TestingModule`. You pull instances with `.get(Token)` (singleton) or `.resolve(Token)` (scoped). Override providers, guards, interceptors, pipes, and filters before compiling.

## Unit: mock a repository provider

Unit-test a service in isolation — provide only the unit under test, mock its collaborators with `overrideProvider`.

```typescript
describe('OrdersService', () => {
  let service: OrdersService;
  const repo = { findById: vi.fn(), save: vi.fn() };

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        OrdersService,
        { provide: OrderRepository, useValue: repo },
      ],
    }).compile();

    service = moduleRef.get(OrdersService);
  });

  it('returns the order', async () => {
    repo.findById.mockResolvedValue({ id: '1', sku: 'A' });
    await expect(service.get('1')).resolves.toMatchObject({ id: '1' });
  });
});
```

`overrideProvider(X).useValue(mock)` is the alternative when the provider is already declared by an imported module:

```typescript
const moduleRef = await Test.createTestingModule({ imports: [OrdersModule] })
  .overrideProvider(OrderRepository)
  .useValue(repo)
  .compile();
```

## e2e: boot the app + Supertest

e2e-test the wired app over HTTP. The trap: a `TestingModule` does **not** apply the globals you set in `main.ts`. Replicate them or the test diverges from production.

```typescript
describe('Orders (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideGuard(AuthGuard)
      .useValue({ canActivate: () => true }) // bypass auth for the route under test
      .compile();

    app = moduleRef.createNestApplication();
    // MIRROR main.ts — without this, validation never runs in the test
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new HttpExceptionFilter());
    await app.init();
  });

  afterAll(async () => app.close());

  it('rejects an unknown property', () =>
    request(app.getHttpServer())
      .post('/orders')
      .send({ sku: 'A', quantity: 1, hacker: true })
      .expect(400));
});
```

## overrideGuard / override others

`overrideGuard`, `overrideInterceptor`, `overridePipe`, `overrideFilter` mirror `overrideProvider`. Use them to neutralize auth or wrap-response behavior that would otherwise complicate the assertion.

## Testing a request-scoped provider

Singletons come from `.get()`; a request-scoped provider must come from `.resolve()`, which returns a Promise and gives a fresh instance per call (per DI sub-tree).

```typescript
const ctx = await moduleRef.resolve(RequestContext);
```

Each `resolve()` is a distinct instance — assert on the one you resolved, not on a `.get()` that would throw for a scoped provider.

## ConfigModule in tests

Provide config explicitly instead of relying on `.env` files leaking into CI:

```typescript
await Test.createTestingModule({
  imports: [ConfigModule.forRoot({ ignoreEnvFile: true, load: [() => ({ JWT_SECRET: 'test' })] })],
  providers: [AuthService],
}).compile();
```

## Vitest vs Jest

NestJS 11's harness moved toward **Vitest** (SWC-powered, fast), and these recipes use `vi.fn()`. Swap to `jest.fn()` if your project is on Jest — Jest is still fully supported and is what `nest new` scaffolds historically. The `Test.createTestingModule` API is identical under both.
