import assert from "assert";
import { TestHelpers, Factory_CollectionDeployedEntity } from "generated";
const { MockDb, Factory } = TestHelpers;

describe("Factory contract CollectionDeployed event tests", () => {
  // Create mock db
  const mockDb = MockDb.createMockDb();

  // Creating mock for Factory contract CollectionDeployed event
  const event = Factory.CollectionDeployed.createMockEvent({
    /* It mocks event fields with default values. You can overwrite them if you need */
  });

  // Processing the event
  const mockDbUpdated = Factory.CollectionDeployed.processEvent({
    event,
    mockDb,
  });

  it("Factory_CollectionDeployedEntity is created correctly", () => {
    // Getting the actual entity from the mock database
    let actualFactoryCollectionDeployedEntity =
      mockDbUpdated.entities.Factory_CollectionDeployed.get(
        `${event.transactionHash}_${event.logIndex}`
      );

    // Creating the expected entity
    const expectedFactoryCollectionDeployedEntity: Factory_CollectionDeployedEntity =
      {
        id: `${event.transactionHash}_${event.logIndex}`,
        tokenAddress: event.params.tokenAddress,
        owner: event.params.owner,
        isERC1155: event.params.isERC1155,
        name: event.params.name,
        symbol: event.params.symbol,
        uri: event.params.uri,
      };
    // Asserting that the entity in the mock database is the same as the expected entity
    assert.deepEqual(
      actualFactoryCollectionDeployedEntity,
      expectedFactoryCollectionDeployedEntity,
      "Actual FactoryCollectionDeployedEntity should be the same as the expectedFactoryCollectionDeployedEntity"
    );
  });
});
