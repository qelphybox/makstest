require 'json'

to_json = -> (_) { def to_json(*a); to_h.to_json(*a); end }
Command = Struct.new(:id, &to_json)
Player = Struct.new(:id, :command_id, &to_json)
Match = Struct.new(:id, :command_1_id, :command_2_id, :order, &to_json)
Achievement = Struct.new(:type, :player_id, :match_id, &to_json)

def create_achievent!(state, type, player_id, match_id)
  state[:achievement] << Achievement.new(type, player_id, match_id)
  File.open("state_#{Time.now.to_i}.json", 'w') do |f|
    f.write(JSON.pretty_generate(state))
  end
  'created'
end

def check_achievement_last_5_matches(state, player_id, type)
  player = state[:player].find { |p| p.id == player_id }

  matches = state[:match].select do |m|
    [m.command_1_id, m.command_2_id].include?(player.command_id)
  end
  match_ids = matches.sort_by { |m| m.order }.last(5).map { |m| m.id }

  state[:achievement].any? do |a|
    match_ids.include?(a.match_id) && player.id == a.player_id && a.type == type
  end
end

def top_5_players(state, type, command_id = nil)
  command = state[:command].find { |p| p.id == command_id }

  player_ids = state[:player]
    .select { |p| p.command_id == command.id }.map(&:id) if command

  score = state[:achievement].each_with_object(Hash.new(0)) do |ach, res|
    next if player_ids&.include?(ach.player_id)
    next if type != ach.type

    res[ach.player_id] += 1
  end

  score.sort_by { |_, v| -v }.to_h.keys.first(5).map do |id|
    state[:player].find { |p| p.id == id }
  end
end

action, state_file_path, *params = ARGV
raw_state = JSON.parse(File.read(state_file_path), symbolize_names: true)
state = raw_state.each_with_object({}) do |(key, values), res|
  clazz = Object.const_get(key.capitalize)
  res[key] = values.map { |v| clazz.new(*v.values_at(*clazz.members)) }
end
puts send(action, state, *params)
