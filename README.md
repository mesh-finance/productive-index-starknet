# ToDos:
    -Modules Registry needs to be finished and integrated. Only official modules should addable via the factory.
    -As of now the Factory always executes `set_strategy_registry` for every index. However it shouldn't do that if the created index doesn't have the strategy_module.

# Modules

On the creation of an index via the index factory, users have the ability to add different features to the index.
Super conservative indices probably want to avoid protocol risk and therefore don't allow for staking/lending.
Some might want to allow for rebalancing, some might not (you need to really trust the person who is allowed to make swaps with the index tokens).
Maybe some indicies want a whitelist for their index.
etc...

The modules/class-hashes/logic selected at the beginning by the user is then available via the index contracts __default__ entry function. 

# Index Factory

A user can mint any given number of indices using the index_factory.cairo contract.
The Factory handles initilaization of the index. This includes the transfer of tokens, configuration of index modules and adding the index to the official index registry.

The interface looks as follows:

```
    func create_index(
        _name: felt,
        _symbol: felt,
        _assets_len: felt,
        _assets: felt*,
        _amounts_len: felt, 
        _amounts: felt*,
        _module_hashes_len: felt,
        _module_hashes: felt*,
        _selectors_len: felt,
        _selectors: felt*
    ) -> (new_index_address: felt):
```
    
The first few parameters are self explanetory:
```
    _name: 		    name of the ERC20 index token
    _symbol: 		symbol of the ERC20 index token
    _assets_len: 	Number of assets that will be part of the index
    _assets:		Addresses of the assets that will be part of the index
    _amounts_len: 	Number of assets that will be part of the index
    _amounts: 		Amount of each individual asset that will be sent to the index as part of the initial mint
```

The last few parameters allows the user to add aditional functionality to the index.
By default the index only allows users to join the index and exit the index. (The index is also an ERC20 by default)
But some people might require more functionality such as: Rebalancing, Strategies, Advanced access controll etc...
    
```
    _module_hashes_len: Length of _module_hashes array (equals number of selectors)
    _module_hashes: 	For each provided _selector, we provide a contract hash that this selector will be attributed to.    
    _selectors_len:	    Length of _selectors array
    _selectors:         Selectors that will be callable via a library call
```

### Example:

A user can add the "strategies" functionality (which enables staking/lending) by adding the class hash of ./modules/strategy_module.cairo as well as the selectors "stake" and "unstake":
    
```
    stake_selector = 1640128135334360963952617826950674415490722662962339953698475555721960042361
    unstake_selector = 1014598069209108454895257238053232298398249443106650014590517510826791002668
    strategy_module hash = 536554312408700354284283040928046824434969893969739486945260186308733942996
    
    Module Hashes Array:
    [
        536554312408700354284283040928046824434969893969739486945260186308733942996,536554312408700354284283040928046824434969893969739486945260186308733942996
    ]

    Selectors Array:
    [
        1640128135334360963952617826950674415490722662962339953698475555721960042361,1014598069209108454895257238053232298398249443106650014590517510826791002668,
    ]
    
```

# Index Registy

The registry allows users/builders to identify an index as an official Mesh Finance index.
Only the factory contract can add indices to the registrty.

# Strategy Registry 

Although later on we might want to allow people to permissionlessly add strategies, for now they should only be able to select from a selected number of audited strategies.
Each staking/lending protocol usually has some unique characteristics (at minimum the addresses are different). Therefore seperate strategies for AAVE, Compound, etc... have to be created and made available to the indices. 
Official strategies can be added to the registry by Mesh Finance. These will then automatically be available for every official index that has the `strategy_module` enabled.
The strategy registry provides the strategy_module with a bunch of helper functions that enables it to handle a wide variant of staking/lending strategies.

# Module Registry

Still work in progress.
The module registry ensures that only official modules (class hashes) are used when minting indices via the factory. Otherwise people could create malicious indicies via the factory.
Official modules are added to the registry by Mesh Finance