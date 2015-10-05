test:
	coverage run --include=ensime_launcher/__init__.py,rplugin/python/ensime.py spec/ensime.py && coverage html
