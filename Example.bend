import Base
import ./FacadeTests.bend as Fixture
import ./Backplane.bend as Backplane
import ./BackplaneTests.bend as BackplaneFixture
import ./Frontend.bend as Frontend
import ./DataOS.bend as DataOS

# Executable example with synthetic authority records from the test fixtures.
# No real data is read, payment collected, OS mount made, or network used.
def main() -> IO(Unit):
  +accepted = Fixture.run(Fixture.context(), 7n, 2n)
  +revoked = Fixture.run(DataOS.Context{BackplaneFixture.context(), Fixture.descriptor(7n, 7),
    Frontend.EmptyRegistry{}}, 7n, 2n)
  do IO<Unit>:
    IO.print("Bend 2 data-isolation library")
    IO.print("Authorized transaction committed: " ++ Bool.show(Backplane.accepted(accepted)))
    IO.print("Original restrictions retained: " ++ Bool.show(BackplaneFixture.retained(accepted)))
    IO.print("Revoked capability committed: " ++ Bool.show(Backplane.accepted(revoked)))
