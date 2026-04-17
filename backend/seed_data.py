import pymysql
import pymysql.cursors
from datetime import date, timedelta

DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 3307,
    "user": "root",
    "password": "",
    "database": "college_bus",
}

def seed():
    conn = pymysql.connect(**DB_CONFIG, cursorclass=pymysql.cursors.DictCursor, autocommit=True)
    try:
        with conn.cursor() as cur:
            print("Clearing old data (trips, stops, routes, gps)...")
            # Clear existing data to avoid duplicates/conflicts during testing
            cur.execute("SET FOREIGN_KEY_CHECKS = 0")
            cur.execute("TRUNCATE TABLE trip_stop_times")
            cur.execute("TRUNCATE TABLE trips")
            cur.execute("TRUNCATE TABLE buses")
            cur.execute("TRUNCATE TABLE routes")
            cur.execute("TRUNCATE TABLE stops")
            cur.execute("TRUNCATE TABLE gps_points")
            cur.execute("SET FOREIGN_KEY_CHECKS = 1")

            print("Inserting Stops...")
            stops = [
                (1, "Saveetha University", 13.028757, 80.019844),
                (2, "Poonamallee", 13.0473, 80.0945),
                (3, "Madhuravoyal", 13.0673, 80.1645),
                (4, "Koyambedu", 13.0732, 80.1912)
            ]
            cur.executemany("INSERT INTO stops (id, name, lat, lng, is_active) VALUES (%s, %s, %s, %s, 1)", stops)

            print("Inserting Routes...")
            routes = [
                (1, "Saveetha University → Koyambedu")
            ]
            cur.executemany("INSERT INTO routes (id, name) VALUES (%s, %s)", routes)

            print("Inserting Buses...")
            buses = [
                (1, "Bus 1", "Saveetha Shuttle")
            ]
            cur.executemany("INSERT INTO buses (id, bus_no, label) VALUES (%s, %s, %s)", buses)

            print("Inserting Trips for Today...")
            today = date.today()
            trips = [
                (1, 1, 1, today, "active")
            ]
            cur.executemany("INSERT INTO trips (id, bus_id, route_id, service_date, status) VALUES (%s, %s, %s, %s, %s)", trips)

            print("Inserting Trip Stop Times...")
            stop_times = [
                (1, 1, 1, "08:00:00", "08:05:00"), # Saveetha
                (1, 2, 2, "08:15:00", "08:17:00"), # Poonamallee
                (1, 3, 3, "08:30:00", "08:32:00"), # Madhuravoyal
                (1, 4, 4, "08:45:00", "08:45:00")  # Koyambedu
            ]
            cur.executemany("INSERT INTO trip_stop_times (trip_id, stop_id, stop_order, sched_arrival, sched_departure) VALUES (%s, %s, %s, %s, %s)", stop_times)

            print("Seeding complete!")

    except Exception as e:
        print(f"Error seeding data: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    seed()
