#!/bin/bash

# Generate some random users
mgodatagen -f "users_config.json" \
    --uri="mongodb+srv://user:password@my.cluster.mongodb.net/"

# Note: I had envisioned trying to use mgodatagen to generate ALL the sample data,
# but this proved more challenging than desired for the sake of this demo particularly because
# I can't make it generate unique ID values.
# So I gave up and created some sample data which I will mongoimport instead.

# Import menu items
mongoimport --uri="mongodb+srv://user:password@my.cluster.mongodb.net/" \
    -d coffeeshop \
    -c products \
    --file="panera_menu.json" --jsonArray

# Import orders
mongoimport --uri="mongodb+srv://user:password@my.cluster.mongodb.net/" \
    -d coffeeshop \
    -c orders \
    --file="panera_orders.json" --jsonArray
