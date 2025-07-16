# The GloVe embeddings file we want to ensure exists
GLOVE_FILE = glove/glove.6B.100d.txt
# The URL to download the zip file from
GLOVE_URL = https://nlp.stanford.edu/data/glove.6B.zip
# Temporary directory for downloads
TMP_DIR = /tmp

all: $(GLOVE_FILE)

$(GLOVE_FILE):
	@echo "GloVe embeddings file not found. Downloading..."
	@mkdir -p glove
	@curl -L -o $(TMP_DIR)/glove.6B.zip $(GLOVE_URL)
	@echo "Extracting glove.6B.100d.txt..."
	@unzip -j $(TMP_DIR)/glove.6B.zip glove.6B.100d.txt -d glove
	@echo "Cleaning up..."
	@rm $(TMP_DIR)/glove.6B.zip
	@echo "Done! GloVe embeddings are now available at $(GLOVE_FILE)"

clean:
	@echo "Removing GloVe embeddings file..."
	@rm -f $(GLOVE_FILE)

.PHONY: all clean
