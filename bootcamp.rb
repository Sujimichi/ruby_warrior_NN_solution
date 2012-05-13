require "./brains.rb"
require "./darwin.rb"

#BOOT CAMP - basic training
#subject neural nets to a pre-defined set of inputs and award points for correct actions
#Boot camp can be run very quickly for several thousand generations to get the population closer to required behavior
#After boot camp the population is transfered to run in the real conditions where the behaviours learnt in boot camp can be refined. 
#
#As well as faster runtimes Bootcamp also provides a smoother gradient for evolution.  In the "real environment" of rubywarior a great many positive 
#selection/mutation events need to happen before any points are awarded atall.  Even in the simpler level the 

class Drills
  attr_accessor :score
  def initialize brain
    @brain = brain
    @score = []
  end

  def test args
    args.each do |input,response| 
      code = response[2]
      points = response[3]
      points ||= 1
      code ||= response.map{|s| s.to_s.each_char.map.first}.join
      @score << (@brain.act_on(input).eql?(response[0..1]) ? (print(code);points) : 0)
    end
  end
end

class BasicTraining
  attr_accessor :ga, :nodes, :gene_length

  def set_config_for n_layers
    @warrior_name = Dir.getwd.split("/").last.sub("-beginner", "")
    @n_layers = n_layers
    nodes_1_layer = {:in => 15, :out => 7}
    nodes_2_layer = {:in => 15, :inner => 8, :out => 7}
    nodes_3_layer = {:in => 15, :inner => 8, :inner2 => 8, :out => 7}
    @nodes = [nodes_1_layer, nodes_2_layer, nodes_3_layer][@n_layers-1] 
    @gene_length = Brain.required_genome_length_for(nodes)
  end

  def train
    @ga.evolve
  end

  def write_best
    genome = @ga.best
    File.open("./genome",'w'){|f| f.write( genome.join(",") )}
  end

  def save_pop
    puts "enter a file name for population"
    f_name = gets.chomp #lvl4-twolayer-population
    return "no filename" if f_name.nil? || f_name.empty?
    pop_file = "./#{f_name}"
    File.open(pop_file,'w'){|f| f.write( @ga.population )}

  end
  def load_pop f_name
    require 'json'
    pop_file = "./#{f_name}"
    p = File.open(pop_file, "r"){|f| f.readlines}
    pop = JSON.parse p.first
    @ga.population = pop
  end

end

#define which brain to use 1, 2 or 3 layered.

class BootCamp < BasicTraining

  def initialize n_layers = 2 
    set_config_for n_layers

    @ga = MGA.new(:generations => 10000, :mutation_rate => 10, :gene_length => @gene_length, :fitness => Proc.new{|genome, gen|
      #puts "\n\n#{genome.join(',')}"
      print "#{gen} |"

      brain = Brains[@n_layers-1].new(@nodes, genome)  
      d = Drills.new(brain)
      r = 1 #representational bias

      #order of inputs; <- /\ -> \/ 
    

      #Basic walking drills - move in only available dir
      d.test( {
        [0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :left],
        [1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :forward],
        [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :forward],
        [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :right],
        [1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :backward],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :forward, '0wf'] #Dont just sit there, do something.
      })

      unless d.score.include?(0) #got to walk before you can attack!
        #Basic Attack - attack enemy in adjacent squares when in open space
        d.test( {
          [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:attack, :left],
          [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:attack, :forward],
          [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, r] => [:attack, :right],
          [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, r] => [:attack, :backward]
        })

        #Basic Attack - attack enemy in closed spaces
        d.test( {
          [1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, r] => [:pivot,  :backward, 'PV'],  #watch your back maggot!
          [1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:attack, :forward, 'AF1'],  #walls either side T infront
          [1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0.1, 1, r] => [:attack, :forward, 'AF2'],  #walls either side T infront attacking
          [1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0.3, 1, r] => [:attack, :forward, 'AF3'],  #walls either side T infront attacking
          [1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0.5, 1, r] => [:attack, :forward, 'AF4'],  #walls either side T infront attacking
          #[1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0.7, 1, r] => [:attack, :forward, 'AF5'],  #walls either side T infront attacking
        
          [1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0.9, 1, r] => [:walk, :backward, 'RetR'],  #walls either side T infront, health low -> retreat
          [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.9, 1, r] => [:walk, :backward, 'RetR']  #walls either side T infront, health low, being shot at -> retreat




          #[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:attack, :forward, 'AF2'],  #walls to left T infront
          #[0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:attack, :forward, 'AF3']   #walls to right T infront
        })

      end

      message = "\t\t - MASTERED BASIC Combat" unless d.score.include?(0)

      unless d.score.include?(0) 

        #learn to recover after fight
        d.test( {
          [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.9, 0, r] => [:rest, :rest, 'R9'],  #recover from 90% damage
          [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.8, 0, r] => [:rest, :rest, 'R8'],  #recover from 80% damage  
          [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.7, 0, r] => [:rest, :rest, 'R7'],  #recover from 70% damage  
          [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.6, 0, r] => [:rest, :rest, 'R6'],  #recover from 50% damage        
          [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.5, 0, r] => [:rest, :rest, 'R5'],  #recover from 50% damage  
          [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.4, 0, r] => [:rest, :rest, 'R4'],  #recover from 40% damage  

          [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.65, 1, r] => [:walk, :forward, 'WFD0'], #limp on if only slightly hurt and under fire (specific example from level 4)
          [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.4, 1, r] => [:walk, :forward, 'WFD1'], #limp on if only slightly hurt and under fire
          [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.2, 1, r] => [:walk, :forward, 'WFD2'],  #limp on if only slightly hurt and under fire

          
        })

      end

      message = "\t\t - Field Medic" unless d.score.include?(0)



      unless d.score.include?(0) #got to fight to be able to rescue!
        #Basic Rescue - rescue captive in adjacent sqaure
        d.test( {
          [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, r] => [:rescue, :left],
          [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, r] => [:rescue, :forward],
          [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, r] => [:rescue, :right],
          [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, r] => [:rescue, :backward]
        }) 
      end

      message = "\t\t - Graduated" unless d.score.include?(0)


      score = d.score.sum.to_i


      print "\t\t- #{score}"
      print message if message
      puts " "
      score

    }) 

  end

  #move 
  def graduate
    ct = CombatTraining.new(@n_layers)
    ct.ga.population = @ga.population
    ct
  end

end

#   bc = BootCamp.new(2); bc.train




class CombatTraining < BasicTraining

  def initialize n_layers
    set_config_for n_layers
    @highest_score = -1000

    @ga =MGA.new(:generations => 5000, :mutation_rate => 10, :gene_length => @gene_length, :fitness => Proc.new{|genome, gen|

      print "#{gen}"

      genome_file = "./genome"
      File.open(genome_file,'w'){|f| f.write( genome.join(",") )}
      invigilator = Invigilator.new(@warrior_name)
      results = `rubywarrior -t 0 -s`

      score, level_score, level_total, n_turns, turn_score, time_bonus, clear_bonus = invigilator.score_results results
      print " | levelscore: #{level_score} | turnscore: #{turn_score.round(2)} | bonus(t:c): #{time_bonus}:#{clear_bonus} | turns: #{n_turns} | Total: #{level_total} | fitnes: #{score.round(2)}"

      if score > @highest_score 
        @highest_score = score
        print "\t\t<----BestSoFar"
      elsif score == @highest_score && score > 0
        print "\t\t<----HighGrade"
      end


      #puts genome.join(",")
      puts "."
      score
    })

  end
end


class AgentTraining < BasicTraining

end

class Invigilator

  def initialize name = Dir.getwd.split("/").last.sub("-beginner", "")
    @warrior_name = Dir.getwd.split("/").last.sub("-beginner", "")
  end

  def score_results results
    
    lines = results.split("\n") 
    turns = results.split("- turn")

    begin
      level_total = lines.select{|line| line.include?("Total Score:")}.first.split("=").last.to_i
      time_bonus = lines.select{|line| line.include?("Time Bonus:")}.first.split(" ").last.to_i if results.include?("Time Bonus:")
      clear_bonus = lines.select{|line| line.include?("Clear Bonus:")}.first.split(" ").last.to_i if results.include?("Clear Bonus:")
    rescue
      level_total = -200 #punishment for failing to complete level
    end

    time_bonus ||= 0
    clear_bonus ||= 0
    #level score based of points awarded during game.  
    level_score = lines.select{|line| line.include?("earns")}.map{|l| l.split[2].to_i}.inject{|i,j| i+j}
    level_score ||= -100 #punishment for not earning anything


    turn_score = []
    turns.each do |turn|

      turn_score << 15 if turn.match(/#{@warrior_name} receives (\d) health/) && !( turn.match(/#{@warrior_name} takes (\d) damage/) || turn.match(/already fit as a fiddle/) )

      %w[forward backward left right].each do |dir|
        turn_score <<  3  if turn.match(/#{@warrior_name} attacks #{dir} and hits/) && !(turn.match(/#{@warrior_name} attacks #{dir} and hits nothing/) || turn.match(/hits Captive/))
        turn_score << -3  if turn.match(/#{@warrior_name} attacks #{dir} and hits/) && (turn.match(/#{@warrior_name} attacks #{dir} and hits nothing/) || turn.match(/hits Captive/))
        turn_score <<  50  if turn.match(/#{@warrior_name} unbinds #{dir} and rescues Captive/)         
      end

      #will already have points for forward attack, this is a bonus for successful forward attack
      turn_score <<  1  if turn.match(/#{@warrior_name} attacks forward and hits/) && !(turn.match(/#{@warrior_name} attacks forward and hits nothing/) || turn.match(/hits Captive/))


      turn_score << -6  if turn.match(/Captive dies/)
      turn_score << -4 if turn.match(/#{@warrior_name} does nothing/)
      turn_score << -4 if turn.match(/#{@warrior_name} walks/) && turn.match(/#{@warrior_name} bumps/)
      turn_score <<  2 if turn.match(/deathbot walks forward/) && !turn.match(/deathbot bumps/)

    end

    turn_score = turn_score.sum
    n_turns = turns.size-1
    turn_score = (turn_score.to_f/n_turns)*4


    bonus = clear_bonus*3 + time_bonus*3 #times three to increase onerous to earn bonuses.


    score = level_score + level_total*2 + turn_score + bonus - (n_turns/10)
    return [score, level_score, level_total, n_turns, turn_score, time_bonus, clear_bonus]
  end

end

#ct = CombatTraining.new(2)
#ct.ga.population = pop.clone
#ct.train


#ga.population = pop

=begin

  @layers = 3
  require './bootcamp.rb'

  bc = BootCamp.new(@layers)
  bc.train



  ct = CombatTraining.new(@layers)
  ct.ga.population = bc.ga.population
  ct.train


=end


#SimpleBrain 
# got a max of 8 points but not alawys
# typical score 6-7
# seems to favor mutation of around 0.8



#Type2Brain 
#
#inner nodes -2
# capable of scoring 12, with v high mutation (ie 4 genes per genome) and after 50000 gens
#
#
#inner nodes - 5
# easily scores 8 with a mutation of 0.1 - 0.3
# got a max of 12 (mutation 0.2 20000 gens)
#
#inner nodes -8 
# got a max of 12 (mutation 0.2 12500 gens)
# got a max of 12 (mutation 0.2 10100 gens)
# got a max of 13 (mutation 0.1 10900 gens)  not common <<----
#
# typically gets 10-11 around 6000 gens
#
#inner nodes - 15
#
#got 10 after long evolution.
#
#



#replace population with BootCamp trained population
#g.population = ga.population
#g.evolve


#select highest scoring member from population and write to file
#genome = g.ordered_population.first

# genome_file = "/home/sujimichi/coding/lab/rubywarrior/deathbot-beginner/genome"
# File.open(genome_file,'w'){|f| f.write( genome.join(",") )}




# pop_file = "/home/sujimichi/coding/lab/rubywarrior/deathbot-beginner/lvl4-twolayer-population"
# require 'json'
# File.open(pop_file,'w'){|f| f.write( good_pop )}
# p = File.open(pop_file, "r"){|f| f.readlines}
# p2 = JSON.parse p.first
#




#g.population.map{|pop_member| puts pop_member.inspect}
#puts "\nevolving"
#g.evolve
#g.population.map{|pop_member| puts pop_member.inspect}

