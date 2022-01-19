FROM python:alpine
COPY . /app
WORKDIR /app
RUN pip3 install -r requirement.txt
CMD python bookstore-api.py
