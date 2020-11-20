build:
	bundle exec jekyll build
serve:
	bundle exec jekyll server --watch --drafts

deploy: build
	rsync -avHp --delete _site/ easyname:/data/web/e11256/html/cyberkov.at/www/
