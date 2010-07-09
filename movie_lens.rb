class MovieLens
  def self.load_movie_lens(path)
    # 映画のタイトルを得る
    movies={}
    open(path+'/u.item') do |f|
      f.each_line do |line|
        id,title = line.split('|')[0,2]
        movies[id] = title
      end
    end

    # データの読み込み
    prefs = {}
    open(path+'/u.data') do |f|
      f.each_line do |line|
        user,movieid,rating,ts = line.split("\t")
        prefs[user] ||= {}
        prefs[user][movies[movieid]]=rating.to_f
      end
    end

    prefs
  end
end
