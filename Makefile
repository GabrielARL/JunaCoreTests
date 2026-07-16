.PHONY: test list contract roundtrip front-page

JULIA ?= julia

test:
	$(JULIA) --project=. test/runtests.jl

list:
	$(JULIA) --project=. test/runtests.jl list

contract:
	$(JULIA) --project=. test/runtests.jl contract

roundtrip:
	JUNA_INTERFACE_ROUNDTRIP=1 $(JULIA) --project=. test/interface_contract.jl

front-page:
	python3 tools/generate_sg1_rankings.py --repo . --out-dir reports
	python3 tools/front_page_matrix.py --repo . --readme README.md
	python3 test/front_page_matrix_contract.py
