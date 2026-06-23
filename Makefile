.PHONY: setup eval test clean

setup:
	pip install -r requirements.txt

eval:
	python -m shipgate.cli --report reports/scorecard.html

test:
	pytest -q

clean:
	rm -rf reports __pycache__ */__pycache__ .pytest_cache
