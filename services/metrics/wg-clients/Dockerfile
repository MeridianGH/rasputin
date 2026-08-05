FROM python:3.12-slim

WORKDIR /app

COPY ./generate-csv.py /app/generate-csv.py

EXPOSE 8000

CMD sh -c "python3 /app/generate-csv.py && python3 -m http.server 8000 --directory /app/csv"
