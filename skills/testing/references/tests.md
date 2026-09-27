# Test design

Use these examples when adding, changing, or reviewing tests.

Examples use C#, xUnit v3, and Awesome Assertions. Follow the repository's actual conventions when they differ.

## Test through the caller's seam

Check results through the seam the caller uses, not through internal collaborators or storage. Query storage or other side channels directly only when persistence itself is the seam under test.

### Prefer

```csharp
[Fact]
public async Task Deactivated_account_is_excluded_from_active_accounts()
{
    await using var db = CreateDbContext();
    var sut = new AccountService(new SqlAccountRepository(db));
    var account = await sut.CreateAsync("Acme");

    await sut.DeactivateAsync(account.Id);

    var active = await sut.ListActiveAsync();

    active.Should().NotContain(a => a.Id == account.Id);
}
```

### Avoid

```csharp
[Fact]
public async Task Deactivated_account_has_inactive_status()
{
    await using var db = CreateDbContext();
    var sut = new AccountService(new SqlAccountRepository(db));
    var account = await sut.CreateAsync("Acme");

    await sut.DeactivateAsync(account.Id);

    db.Accounts.Single(a => a.Id == account.Id).Status.Should().Be(AccountStatus.Inactive);
}
```

The second test proves a column changed, not that callers stop seeing the account. It still passes when `ListActiveAsync` ignores status.

## Derive expectations independently

Expected values should come from requirements, worked examples, or known values.

Do not reproduce the production algorithm in the assertion.

### Prefer

```csharp
[Fact]
public void Ten_percent_discount_returns_90()
{
    var sut = new DiscountCalculator();

    var result = sut.Calculate(100m, 10m);

    result.Should().Be(90m);
}
```

### Avoid

```csharp
[Fact]
public void Discount_returns_calculated_expected_amount()
{
    const decimal rate = 100m;
    const decimal discountPercent = 10m;

    var expected = rate - (rate * discountPercent / 100m);

    var sut = new DiscountCalculator();

    var result = sut.Calculate(rate, discountPercent);

    result.Should().Be(expected);
}
```

The second test can repeat the same mistake as the implementation.

## Use domain language

Test names and expectations should describe the behavior in terms used by the repository.

### Prefer

```csharp
[Fact]
public void Agreement_discount_returns_agreed_rate()
{
    var sut = new AgreementRateCalculator();

    var result = sut.Calculate(walkInRate: 100m, discountPercent: 10m);

    result.Should().Be(90m);
}
```

### Avoid

```csharp
[Fact]
public void Calculate_returns_correct_value()
{
    // ...
}
```

## Keep one authoritative test level

Do not repeat the same assertion at unit, integration, and E2E levels only for additional reassurance. A higher-level test earns its place when that boundary introduces another failure mode, such as:

- persistence or query behavior
- serialization
- dependency configuration
- HTTP contracts
- authentication or authorization
- communication across deployable boundaries

## Prefer focused assertions

Assert the behavior relevant to the test rather than unrelated properties of the result.

### Prefer

```csharp
[Fact]
public void Valid_input_creates_active_account()
{
    var account = Account.Create("Acme");

    account.Status.Should().Be(AccountStatus.Active);
}
```

Avoid asserting every property of an object unless the complete object shape is part of the behavior being tested.
