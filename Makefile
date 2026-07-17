.PHONY: test list contract roundtrip record-frame-benchmark \
	record-sg1-rpchan-baseline front-page

JULIA ?= julia

test:
	$(JULIA) --project=. test/runtests.jl

list:
	$(JULIA) --project=. test/runtests.jl list

contract:
	$(JULIA) --project=. test/runtests.jl contract

roundtrip:
	JUNA_INTERFACE_ROUNDTRIP=1 $(JULIA) --project=. test/interface_contract.jl

record-frame-benchmark:
	$(JULIA) --project=. tools/record_commit_frame_benchmark.jl

record-sg1-rpchan-baseline:
	$(JULIA) --project=. tools/record_sg1_rpchan_five_algorithms.jl

front-page:
	python3 tools/generate_sg1_rankings.py --repo . --out-dir reports
	python3 tools/front_page_matrix.py --repo . --readme README.md
	python3 test/front_page_matrix_contract.py
