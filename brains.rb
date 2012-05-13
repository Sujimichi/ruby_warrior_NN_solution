class Brains
  def self.[] n
    const = self.constants[n]
    return unless const
    Brains.const_get(const)
  end
end

class Brain
  class Migraine < Exception;end

  #act_on takes inputs from world sensors as an array which is presented to the neural network in @network
  #the neural network in @network will return an output array which act_on will interpret into an 'action' and an 'impulse' 
  #(returned as array [action, impulse]
  #The action is one of the warriors err actions (duh), the impulse is the direction to perform that action. ie: [:walk, :forward]
  def act_on inputs
    output = @network.process(inputs) #send inputs to neural net and return result.
    #puts "neural output:\n#{output}"
   
    #First two output nodes of network will define impulse.  Impulse is the direction for an action ie walk! or attack!
    #First node represents impulse to go forward or backwards, +ive => forward, -ive backward.
    #Second node represents impulse to go left or right, , +ive => left, -ive right.
    #which ever impulse (forward/back or left/right) is absolutely stronger will be the one taken
    #If both nodes are between -0.5 and +0.5 then it will rest. Think joy stick

    #if output[0] >= -0.5 && output[0] <= 0.5 && output[1] >= -0.5 && output[1] <= 0.5 
      #impulse = :rest
    if output[0].abs > output[1].abs #moving forward or backwards
      impulse = (output[0] > 0) ? :forward : :backward
    else #moving left or right
      impulse = (output[1] > 0) ? :left : :right
    end

    #inpulse = :pivot if output[0] <= -3.0 && output[1].abs >= 3.0 #pull hard back and turn hard in either direction to pivot!

    
    #The other nodes each represent an action.  Which ever node is stimulated most is the action taken.
    actions = [[:walk, output[2]], [:attack, output[3]], [:rest, output[4]], [:rescue, output[5]], [:pivot, output[6]]]
    action = actions.max_by{|grp| grp.last}.first 
    impulse = :rest if action.eql?(:rest)
    impulse = :backward if action.eql?(:pivot)
  
    return [action, impulse]
  end

  #check that the genome is appropriate size for given nodes and raise exception if not.
  def sane? 
    rs = Brain.required_genome_length_for(@nodes)
    unless @genome.size.eql?(rs)
      raise Migraine.new("genome is incorrect size for node configutation.  Genome should be #{rs} bits, it is #{@genome.size}")  
    end
  end

  #return the expected genome length based on the number of nodes in the network.
  def self.required_genome_length_for nodes
    type = nodes.keys.join
    case type
    when "inout" #single layer
      gl = (nodes[:in] * nodes[:out])      
    when "ininnerout" #two layer
      gl = (nodes[:in] * nodes[:inner]) + (nodes[:inner] * nodes[:out])
    when "ininnerinner2out" #three layer
      gl = (nodes[:in] * nodes[:inner]) + (nodes[:inner] * nodes[:inner2]) + (nodes[:inner2] * nodes[:out])
    end
    gl
  end
end


#  brain = SimpleBrain.new({:in => 13, :out => 5}, [<genome>])
#  brain.act_on(inputs)
class Brains::WBush < Brain 
  def initialize nodes, genome
    @nodes, @genome = nodes, genome
    self.sane?
    weights = genome.in_groups_of(nodes[:in])
    @network = NeuralNetwork.new([NeuralLayer.new(weights)])
  end
end

#  brain = Type2Brain.new({:in => 13, :inner => 8, :out => 5}, [<genome>])
#  brain.act_on(inputs)
class Brains::Type2 < Brain
  def initialize nodes, genome
    @nodes, @genome = nodes, genome
    self.sane?
    p1 = (nodes[:in] * nodes[:inner])
    weights1 = genome[0..p1-1].in_groups_of(nodes[:in])
    weights2 = genome[p1..(genome.size-1)].in_groups_of(nodes[:inner])
    @network = NeuralNetwork.new([NeuralLayer.new(weights1), NeuralLayer.new(weights2)])
  end
end

#  brain = RiverTam.new({:in => 13, :inner => 8, , :inner2 => 8, :out => 5}, [<genome>])
#  brain.act_on(inputs)
class Brains::RiverTam < Brain
  def initialize nodes, genome
    @nodes, @genome = nodes, genome
    self.sane?
    p1 = (nodes[:in] * nodes[:inner])
    p2 = p1 + (nodes[:inner] * nodes[:inner2]) 
    weights1 = genome[0..p1-1].in_groups_of(nodes[:in])
    weights2 = genome[p1..p2-1].in_groups_of(nodes[:inner])
    weights3 = genome[p2..(genome.size-1)].in_groups_of(nodes[:inner2]) 
    @network = NeuralNetwork.new([NeuralLayer.new(weights1), NeuralLayer.new(weights2), NeuralLayer.new(weights3)])
  end
end

class NeuralNetwork

  def initialize layers
    @layers = layers
  end

  def process inputs
    output = inputs
    @layers.each do |layer|
      output = layer.process(output)
    end
    output
  end
end

class NeuralLayer
  def initialize weights 
    @weights = weights
    @nodes = {:output => @weights.size, :input => @weights.first.size}
  end
 
  def process inputs
    #inputs = inputs[0..@weights.first.size-1] #ensure inputs size lines up with size of weights.  ignoring extra input
    @nodes[:output].times.map{ |i| inputs.zip(@weights[i]).map{|d| d.product_with_activation}.sum.round(2) }
  end
end

class Array
  
  #return the product of the array
  def product
    self.inject{|i,j| i.to_f * j.to_f}
  end
  
  #return the activiated product.  For use in neural networks.  The product is passed through a sin function.
  def product_with_activation
    Math.sin(product)
  end
  
  #return the summed value of the array
  def sum
    self.inject{|i,j| i.to_f + j.to_f}
  end

  #divide the array into n separate arrays.
  def in_groups_of n
    col = []
    self.each_slice(n){|slice| col << slice}
    return col
  end
end


#move to non-binary genome <---
#normalize input from health
#remove rest! from rescue block and add specific node.
#
