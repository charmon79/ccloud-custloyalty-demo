#!/bin/bash

# Import users/customers
mongoimport --uri="mongodb+srv://user:password@my.cluster.mongodb.net/" \
    -d coffeeshop \
    -c products \
    --file="coffeeshop.users.json" --jsonArray

# Import menu items
mongoimport --uri="mongodb+srv://user:password@my.cluster.mongodb.net/" \
    -d coffeeshop \
    -c products \
    --file="coffeeshop.menu.json" --jsonArray

# Import orders
mongoimport --uri="mongodb+srv://user:password@my.cluster.mongodb.net/" \
    -d coffeeshop \
    -c orders \
    --file="coffeeshop.orders.json" --jsonArray
