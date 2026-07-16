.PHONY: test list contract roundtrip

JULIA ?= julia

test:
	$(JULIA) --project=. test/runtests.jl

list:
	$(JULIA) --project=. test/runtests.jl list

contract:
	$(JULIA) --project=. test/runtests.jl contract

roundtrip:
	JUNA_INTERFACE_ROUNDTRIP=1 $(JULIA) --project=. test/interface_contract.jl
