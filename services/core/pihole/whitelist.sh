#!/bin/bash
(
  until /usr/local/bin/pihole status | grep -q "Pi-hole blocking is enabled"; do
    sleep 2
  done
  sleep 5

  pihole allow mparticle.weather.com
  pihole --allow-regex 'mask(-h2)?\.icloud\.com'
) &
exit 0
