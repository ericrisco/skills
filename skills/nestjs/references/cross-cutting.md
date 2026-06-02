# Cross-cutting layer: deep treatment

Guards, interceptors, pipes, and filters share one base idea — they read the `ExecutionContext` and run at a fixed point in the request lifecycle — but each has a distinct job. This is the depth the SKILL body points to.

## ExecutionContext

Every cross-cutting primitive receives an `ExecutionContext` (a superset of `ArgumentsHost`). It abstracts the transport so the same guard works over HTTP, WebSockets, or microservices.

```typescript
@Injectable()
export class AuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<Request>();
    return Boolean(req.headers.authorization);
  }
}
```

Pull request data from the context here, not from an injected request-scoped provider — guards run before the scope you expect is settled.

## Custom param decorators

Extract repeated `req.user` plumbing into a decorator built on `createParamDecorator`:

```typescript
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext) => {
    return ctx.switchToHttp().getRequest().user;
  },
);

// handler
@Get('me')
me(@CurrentUser() user: User) { return user; }
```

## Reflector + SetMetadata: role and @Public() guards

Attach metadata at the route/controller with a decorator, read it in the guard with `Reflector`. This is how you build role checks and a `@Public()` opt-out for a global guard.

```typescript
export const IS_PUBLIC = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC, true);

export const ROLES = 'roles';
export const Roles = (...roles: string[]) => SetMetadata(ROLES, roles);
```

```typescript
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const required = this.reflector.getAllAndOverride<string[]>(ROLES, [
      context.getHandler(),
      context.getClass(),
    ]);
    const req = context.switchToHttp().getRequest();
    if (!required?.length) return Boolean(req.user);
    return required.some((r) => req.user?.roles?.includes(r));
  }
}
```

`getAllAndOverride` merges handler-level over class-level metadata — route decorator wins over controller decorator. Bind this guard globally and DI-capable via `APP_GUARD` so `Reflector` is injected:

```typescript
@Module({ providers: [{ provide: APP_GUARD, useClass: AuthGuard }] })
export class AppModule {}
```

## Interceptors (RxJS)

Interceptors wrap the handler. The pre-handler code runs before `next.handle()`; the operators you pipe onto the returned stream run after. They are RxJS observables — use `map`, `tap`, `timeout`, `catchError`.

Response transform:

```typescript
@Injectable()
export class WrapResponseInterceptor implements NestInterceptor {
  intercept(_ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(map((data) => ({ data, ts: Date.now() })));
  }
}
```

Timeout:

```typescript
@Injectable()
export class TimeoutInterceptor implements NestInterceptor {
  intercept(_ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(
      timeout(5000),
      catchError((err) =>
        err instanceof TimeoutError
          ? throwError(() => new RequestTimeoutException())
          : throwError(() => err),
      ),
    );
  }
}
```

## Exception filters

A filter catches thrown errors and shapes the response. Declare what it catches with `@Catch(...)`; an empty `@Catch()` catches everything.

```typescript
@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();
    const status = exception.getStatus();
    res.status(status).json({
      statusCode: status,
      message: exception.message,
      timestamp: new Date().toISOString(),
    });
  }
}
```

Bind globally and DI-capable via `APP_FILTER`. Filters run last in the lifecycle, so they see anything thrown by guards, pipes, interceptors, or the handler.

## Order when multiple are bound

Within a kind, binding order is global → controller → route. Across kinds, the lifecycle order holds: guards → interceptors(pre) → pipes → handler → interceptors(post) → filters. A pipe cannot see what a later interceptor does; a guard cannot read a pipe-transformed DTO. When you need data shaped before authorization, that is a sign the work belongs in a guard's own context read, not downstream.
