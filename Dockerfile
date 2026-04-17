FROM lthub/moodle:4.5.10

USER root

# Bake this local plugin into the Moodle image.
COPY . /bitnami/moodle/local/hlai_quizgen

# Ensure Moodle runtime user can read plugin files.
RUN chown -R 1001:0 /bitnami/moodle/local/hlai_quizgen

USER 1001
