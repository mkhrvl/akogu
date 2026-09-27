# Test design

Use these examples when adding, changing, or reviewing tests.

Examples use C#, xUnit v3, and Awesome Assertions. Follow the repository's actual conventions when they differ.

## Test observable behavior

Prefer assertions against behavior visible through a stable public seam.

Avoid tests whose primary assertion is that an internal collaborator was called.

### Prefer

```csharp
[Fact]
public async Task Created_account_can_be_retrieved()
{
    var repository = new InMemoryAccountRepository();
    var sut = new AccountService(repository);

    var created = await sut.CreateAsync("Acme");

    var account = await sut.GetAsync(created.Id);

    account.Should().NotBeNull();
    account!.Name.Should().Be("Acme");
}
```

### Avoid

```csharp
[Fact]
public async Task Repository_save_is_called()
{
    var repository = new RecordingAccountRepository();
    var sut = new AccountService(repository);

    await sut.CreateAsync("Acme");

    repository.SaveCallCount.Should().Be(1);
}
```

The first test describes behavior. The second primarily describes the current implementation.

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

Put a behavior at the cheapest level that reliably owns its failure mode.

Do not repeat the same assertion at unit, integration, and E2E levels only for additional reassurance.

Add a higher-level test when that boundary introduces another meaningful failure mode, such as:

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
