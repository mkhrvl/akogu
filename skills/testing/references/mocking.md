# Mocking

Use test doubles to isolate meaningful boundaries, not to reproduce the implementation inside the test.

Follow the repository's existing mocking and test-double conventions.

## Mock boundaries

Test doubles are useful for dependencies whose real behavior would make the test slow, nondeterministic, destructive, or dependent on another system.

Typical boundaries include:

- external APIs
- email, messaging, and other outbound communication
- clocks and time
- randomness
- filesystem or operating-system interactions
- other remote or nondeterministic dependencies

Prefer the real in-process implementation when it is cheap and deterministic.

## Assert behavior at the boundary

When replacing an external boundary, assert the meaningful interaction with that boundary rather than interactions between internal collaborators.

### Prefer

```csharp
[Fact]
public async Task Invitation_sends_setup_email()
{
    var emailGateway = new RecordingEmailGateway();
    var sut = new InvitationService(emailGateway);

    await sut.InviteAsync("user@example.com");

    emailGateway.Sent.Should().ContainSingle();

    var email = emailGateway.Sent.Single();
    email.Recipient.Should().Be("user@example.com");
    email.Subject.Should().Be("Set up your account");
}
```

The email gateway represents an external effect, so observing the outgoing message is part of the behavior.

## Avoid mocking internal collaborators

Do not replace internal collaborators merely so the test can verify the same call structure as the implementation.

### Avoid

```csharp
[Fact]
public async Task Composer_and_gateway_are_called()
{
    var composer = new RecordingInvitationComposer();
    var gateway = new RecordingEmailGateway();
    var sut = new InvitationService(composer, gateway);

    await sut.InviteAsync("user@example.com");

    composer.CallCount.Should().Be(1);
    gateway.SendCallCount.Should().Be(1);
}
```

This couples the test to orchestration that may change without changing observable behavior.

## Control nondeterminism

Replace nondeterministic boundaries when the value itself matters to the behavior.

### Prefer

```csharp
[Fact]
public void Setup_token_expires_24_hours_after_creation()
{
    var now = new DateTimeOffset(2026, 8, 31, 10, 0, 0, TimeSpan.Zero);
    var clock = new FixedClock(now);
    var sut = new SetupTokenService(clock);

    var token = sut.CreateToken();

    token.ExpiresAt.Should().Be(
        new DateTimeOffset(2026, 9, 1, 10, 0, 0, TimeSpan.Zero));
}
```

A fixed clock makes the behavior deterministic without coupling the test to internal calls.

## Prefer state over interaction when either works

When the resulting state can be observed reliably, prefer asserting that state.

Use interaction assertions when the interaction itself is the externally meaningful behavior, such as sending a message or calling an external system.
