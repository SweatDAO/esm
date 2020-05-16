# ESM

Emergency Shutdown Module

## Description

The ESM is a contract with the ability to call `globalSettlement.shutdownSystem()`, i.e. trigger an
Emergency Shutdown (aka Global Settlement).

Protocol token holders `burnTokens`. When the ESM's internal `burntTokens` balance is equal to or greater than the `triggerThreshold`, the ESM can be `shutdown`.

It is meant to be used by a protocol token minority to thwart two types of attack:

* malicious governance
* critical bug

In the former case, the pledgers will have no expectation of recovering the funds (as that would require a malicious majority to pass the required vote), and their only option is to set up an alternative fork in which the majority's funds are slashed.

In the latter case, governance can choose to refund the ESM pledgers by minting new tokens.

If governance wants to disarm the ESM, it can only do so by removing its authorization to call `globalSettlement.shutdownSystem()`.

## Invariants

* `shutdown` can be called by anyone
* `shutdown` can be called only once
* `shutdown` requires `burntTokens` to be >= `triggerThreshold`
* `burnTokens` can only be called before `shutdown`
* tokens are burnt immediately upon `burnTokens`
