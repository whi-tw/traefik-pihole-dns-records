#!/usr/bin/env ruby
require("docker")


$traefik_container_name = ENV["TRAEFIK_CONTAINER_NAME"]
$traefik_ip = ENV["TRAEFIK_IP"]
unless $traefik_container_name || $traefik_ip
  puts "TRAEFIK_CONTAINER_NAME or TRAEFIK_IP must be set"
  exit 1
end
$pihole_container_name = ENV["PIHOLE_CONTAINER_NAME"]
unless $pihole_container_name
  puts "PIHOLE_CONTAINER_NAME must be set"
  exit 1
end
$rule_file_name = ENV["RULE_FILE_NAME"]
unless $rule_file_name
  puts "RULE_FILE_NAME must be set"
  exit 1
end

def find_pihole_container(contname)
  return Docker::Container.get(contname)
end

def find_traefik_listen_ip(contname)
  return Docker::Container.get(contname).json["NetworkSettings"]["Ports"]["80/tcp"][0]["HostIp"]
end

def get_containers_with_rule_label()
  return Docker::Container.all(all: true, filters: { label: [ "traefik.frontend.rule" ] }.to_json)
end

def extract_hostname_from_container(container)
  rule_label = container.json["Config"]["Labels"]["traefik.frontend.rule"]
  rule_label.split(";").map do |pair|
    k, v = pair.split(":", 2)
    next if k != "Host"
    return v
  end
end

def extract_hostname_from_actor(actor)
  if actor.attributes["traefik.frontend.rule"] then
    rule_label = actor.attributes["traefik.frontend.rule"]
    rule_label.split(";").map do |pair|
      k, v = pair.split(":", 2)
      next if k != "Host"
      return v
    end
  end
  return false
end

def generate_host_record_line(hostname, traefik_ip)
  return "host-record=#{hostname.to_s},#{traefik_ip.to_s}"
end

def get_existing_records(container)
  file = container.read_file("/etc/dnsmasq.d/#{$rule_file_name}")
  rules = {}
  file.split("\n").each do | rule |
    rulesplit = rule.split("=")[1].split(",")
    rules[rulesplit[0]] = rulesplit[1]
  end
  return rules
end

def add_or_update_rule(existing_rules, hostname, ip)
  if existing_rules[hostname] == ip then
    return false
  else
    existing_rules[hostname] = ip
    return existing_rules
  end
end
def remove_rule(existing_rules, hostname)
  if existing_rules[hostname]
    existing_rules.delete(hostname)
    return existing_rules
  else
    return false
  end
end

pihole = find_pihole_container($pihole_container_name)
unless $traefik_ip
  traefik_ip = find_traefik_listen_ip($traefik_container_name)
end
rules_to_set = []
get_containers_with_rule_label().each do | container |
  hostname = extract_hostname_from_container(container)
  rules_to_set.push(generate_host_record_line(hostname, $traefik_ip))
end
rulefiletext = rules_to_set.join("\n")

pihole.store_file("/etc/dnsmasq.d/#{$rule_file_name}", rulefiletext)
pihole.exec(['pihole', 'restartdns']) { |stream, chunk| puts "#{stream}: #{chunk}" }

Docker.options[:read_timeout] = 86400
Docker::Event.stream do |event|
  if event.type == "container" then
    event_hostname = extract_hostname_from_actor(event.actor)
    if event_hostname then
      if event.action == "start" then
        existing_rules = get_existing_records(pihole)
        newrules = add_or_update_rule(existing_rules, event_hostname, $traefik_ip)
        if newrules then
          rules_as_text = []
          newrules.each do | hostname, ip |
            rules_as_text.push(generate_host_record_line(hostname, ip))
          end
          rulefiletext = rules_as_text.join("\n")
          pihole.store_file("/etc/dnsmasq.d/#{$rule_file_name}", rulefiletext)
          pihole.exec(['pihole', 'restartdns']) { |stream, chunk| puts "#{stream}: #{chunk}" }
          puts "Added new DNS entry: #{event_hostname} => #{traefik_ip}"
        end
      elsif event.action == "die" then
        existing_rules = get_existing_records(pihole)
        newrules = remove_rule(existing_rules, event_hostname)
        if newrules then
          rules_as_text = []
          newrules.each do | hostname, ip |
            rules_as_text.push(generate_host_record_line(hostname, ip))
          end
          rulefiletext = rules_as_text.join("\n")
          pihole.store_file("/etc/dnsmasq.d/#{$rule_file_name}", rulefiletext)
          pihole.exec(['pihole', 'restartdns']) { |stream, chunk| puts "#{stream}: #{chunk}" }
          puts "Removed DNS entry: #{event_hostname}"
        end
      end
    end
  end
end
